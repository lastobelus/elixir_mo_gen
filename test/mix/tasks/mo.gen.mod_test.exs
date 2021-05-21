Code.require_file("../../mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Mo.Gen.ModTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Mo.Gen

  setup do
    Mix.Task.clear()
    Application.put_env(:mo_gen, :ignore_paths, nil)
    :ok
  end

  test "generates module and test file", config do
    in_tmp_project(config.test, fn ->
      Gen.Mod.run(~w(/some/namespace/new_module -q))

      assert_file("lib/some/namespace/new_module.ex", fn file ->
        assert file =~ "defmodule Some.Namespace.NewModule do"
      end)

      assert_file("test/some/namespace/new_module_test.exs", fn file ->
        assert file =~ "defmodule Some.Namespace.NewModuleTest do"
      end)
    end)
  end

  test "generates multiple files", config do
    in_tmp_project(config.test, fn ->
      Gen.Mod.run(~w(some/namespace/new_module other/other_module -q))

      assert_file("lib/elixir_mo_gen_test/some/namespace/new_module.ex", fn file ->
        assert file =~ "defmodule ElixirMoGenTest.Some.Namespace.NewModule do"
      end)

      assert_file("test/elixir_mo_gen_test/some/namespace/new_module_test.exs", fn file ->
        assert file =~ "defmodule ElixirMoGenTest.Some.Namespace.NewModuleTest do"
      end)

      assert_file("lib/elixir_mo_gen_test/other/other_module.ex", fn file ->
        assert file =~ "defmodule ElixirMoGenTest.Other.OtherModule do"
      end)

      assert_file("test/elixir_mo_gen_test/other/other_module_test.exs", fn file ->
        assert file =~ "defmodule ElixirMoGenTest.Other.OtherModuleTest do"
      end)
    end)
  end

  test "handles names with dots like mo.gen.mod", config do
    in_tmp_project(config.test, fn ->
      Gen.Mod.run(~w(some/namespace/mo.gen.mod -q))

      assert_file("lib/elixir_mo_gen_test/some/namespace/mo.gen.mod.ex", fn file ->
        assert file =~ "defmodule ElixirMoGenTest.Some.Namespace.Mo.Gen.Mod do"
      end)

      assert_file("test/elixir_mo_gen_test/some/namespace/mo.gen.mod_test.exs", fn file ->
        assert file =~ "defmodule ElixirMoGenTest.Some.Namespace.Mo.Gen.ModTest do"
      end)
    end)
  end

  test "handles CamelCase names", config do
    in_tmp_project(config.test, fn ->
      Gen.Mod.run(~w(MySpace.MyCamelThing -q))

      assert_file("lib/elixir_mo_gen_test/my_space/my_camel_thing.ex", fn file ->
        assert file =~ "defmodule ElixirMoGenTest.MySpace.MyCamelThing do"
      end)

      assert_file("test/elixir_mo_gen_test/my_space/my_camel_thing_test.exs", fn file ->
        assert file =~ "defmodule ElixirMoGenTest.MySpace.MyCamelThingTest do"
      end)
    end)
  end

  test "handles `.ex` included in name", config do
    in_tmp_project(config.test, fn ->
      File.mkdir!("lib/some")
      Gen.Mod.run(~w(Some.NewModule -q))

      assert_file("lib/some/new_module.ex", fn file ->
        assert file =~ "defmodule Some.NewModule do"
      end)
    end)
  end

  test "when name doesn't start with lib adds to `lib/my_app` unless first segment exists or starts with slash",
       config do
    in_tmp_project(config.test, fn ->
      File.mkdir!("lib/exists")

      Gen.Mod.run(~w(exists/new_module doesnt_exist/other_module -q))

      refute_file("lib/elixir_mo_gen_test/new_module.ex")
      refute_file("lib/elixir_mo_gen_test/exists/new_module.ex")
      assert_file("lib/exists/new_module.ex")

      refute_file("lib/doesnt_exist/other_module.ex")
      assert_file("lib/elixir_mo_gen_test/doesnt_exist/other_module.ex")
    end)
  end

  describe "ignore_paths" do
    test "ignores paths configured in config()[:mo_gen][:ignore_paths]", config do
      Application.put_env(:mo_gen, :ignore_paths, "not_this")

      in_tmp_project(config.test, fn ->
        Gen.Mod.run(~w(/some/namespace/not_this/new_module -q))

        assert_file("lib/some/namespace/not_this/new_module.ex", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModule do"
        end)

        assert_file("test/some/namespace/not_this/new_module_test.exs", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModuleTest do"
        end)
      end)

      Application.put_env(:mo_gen, :ignore_paths, ["not_this", "or_this"])

      in_tmp_project(config.test, fn ->
        Gen.Mod.run(~w(/some/namespace/not_this/or_this/new_module -q))

        assert_file("lib/some/namespace/not_this/or_this/new_module.ex", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModule do"
        end)

        assert_file("test/some/namespace/not_this/or_this/new_module_test.exs", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModuleTest do"
        end)
      end)

      Application.put_env(:mo_gen, :ignore_paths, "not_this,or_this")

      in_tmp_project(config.test, fn ->
        Gen.Mod.run(~w(/some/namespace/not_this/or_this/new_module -q))

        assert_file("lib/some/namespace/not_this/or_this/new_module.ex", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModule do"
        end)

        assert_file("test/some/namespace/not_this/or_this/new_module_test.exs", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModuleTest do"
        end)
      end)
    end

    test "ignores paths passed with --ignore_paths", config do
      in_tmp_project(config.test, fn ->
        Gen.Mod.run(
          ~w(/some/namespace/not_this/or_this/new_module --ignore-paths not_this --ignore-paths or_this -q)
        )

        assert_file("lib/some/namespace/not_this/or_this/new_module.ex", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModule do"
        end)

        assert_file("test/some/namespace/not_this/or_this/new_module_test.exs", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModuleTest do"
        end)
      end)
    end

    test "it creates a template when --template is true", config do
      in_tmp_project(config.test, fn ->
        Gen.Mod.run(~w(/some/namespace/new_module -t -q))

        assert_file("lib/some/namespace/new_module.html.leex", fn file ->
          assert file =~ "<!-- Some.Namespace.NewModule -->"
        end)
      end)
    end
  end

  describe "phoenix" do
    test "does not add standard ignore paths to namespace", config do
      in_tmp_phx_project(config.test, fn ->
        Gen.Mod.run(~w(web/controllers/new_controller -q))

        assert_file("lib/elixir_mo_gen_test_web/controllers/new_controller.ex", fn file ->
          assert file =~ "defmodule ElixirMoGenTestWeb.NewController do"
        end)

        assert_file("test/elixir_mo_gen_test_web/controllers/new_controller_test.exs", fn file ->
          assert file =~ "defmodule ElixirMoGenTestWeb.NewControllerTest do"
        end)
      end)
    end

    test "when name starts with web adds to `lib/my_app_web` unless `lib/web` exists", config do
      in_tmp_phx_project(config.test, fn ->
        Gen.Mod.run(~w(web/some/new_module -q))
        refute_file("lib/web/new_module.ex")
        assert_file("lib/elixir_mo_gen_test_web/some/new_module.ex")
      end)
    end

    test "it parses module_name:alias to add `use MyAppWeb, :alias` statement", config do
      in_tmp_phx_project(config.test, fn ->
        Gen.Mod.run(~w(
          web/controllers/new_controller:c
          web/views/my_view:v
          -q
          ))

        assert_file("lib/elixir_mo_gen_test_web/controllers/new_controller.ex", fn file ->
          assert file =~ "defmodule ElixirMoGenTestWeb.NewController do"
          assert file =~ "use ElixirMoGenTestWeb, :controller"
        end)

        assert_file("lib/elixir_mo_gen_test_web/views/my_view.ex", fn file ->
          assert file =~ "defmodule ElixirMoGenTestWeb.MyView do"
          assert file =~ "use ElixirMoGenTestWeb, :view"
        end)
      end)
    end
  end

  describe "generated tests" do
    test "the generated test runs, and flunks", config do
      in_tmp_project(config.test, fn ->
        Gen.Mod.run(~w(some/namespace/new_module -q))

        {mix_test_status, output} = run_mix_test(config.test)

        assert mix_test_status == :error, "`mix test` should have flunked"

        assert output =~
                 ~S/code: flunk("no tests for #{ElixirMoGenTest.Some.Namespace.NewModule} yet!")/

        assert output =~ "1 test, 1 failure"
      end)
    end
  end
end
