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
      Gen.Mod.run(~w(some/namespace/new_module -q))

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

      assert_file("lib/some/namespace/new_module.ex", fn file ->
        assert file =~ "defmodule Some.Namespace.NewModule do"
      end)

      assert_file("test/some/namespace/new_module_test.exs", fn file ->
        assert file =~ "defmodule Some.Namespace.NewModuleTest do"
      end)

      assert_file("lib/other/other_module.ex", fn file ->
        assert file =~ "defmodule Other.OtherModule do"
      end)

      assert_file("test/other/other_module_test.exs", fn file ->
        assert file =~ "defmodule Other.OtherModuleTest do"
      end)
    end)
  end

  test "handles names with dots like mo.gen.mod", config do
    in_tmp_project(config.test, fn ->
      Gen.Mod.run(~w(some/namespace/mo.gen.mod -q))

      assert_file("lib/some/namespace/mo.gen.mod.ex", fn file ->
        assert file =~ "defmodule Some.Namespace.Mo.Gen.Mod do"
      end)

      assert_file("test/some/namespace/mo.gen.mod_test.exs", fn file ->
        assert file =~ "defmodule Some.Namespace.Mo.Gen.ModTest do"
      end)
    end)
  end

  describe "ignore_paths" do
    test "ignores paths configured in config()[:mo_gen][:ignore_paths]", config do
      Application.put_env(:mo_gen, :ignore_paths, "not_this")

      in_tmp_project(config.test, fn ->
        Gen.Mod.run(~w(some/namespace/not_this/new_module -q))

        assert_file("lib/some/namespace/not_this/new_module.ex", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModule do"
        end)

        assert_file("test/some/namespace/not_this/new_module_test.exs", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModuleTest do"
        end)
      end)

      Application.put_env(:mo_gen, :ignore_paths, ["not_this", "or_this"])

      in_tmp_project(config.test, fn ->
        Gen.Mod.run(~w(some/namespace/not_this/or_this/new_module -q))

        assert_file("lib/some/namespace/not_this/or_this/new_module.ex", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModule do"
        end)

        assert_file("test/some/namespace/not_this/or_this/new_module_test.exs", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModuleTest do"
        end)
      end)

      Application.put_env(:mo_gen, :ignore_paths, "not_this,or_this")

      in_tmp_project(config.test, fn ->
        Gen.Mod.run(~w(some/namespace/not_this/or_this/new_module -q))

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
          ~w(some/namespace/not_this/or_this/new_module --ignore-paths not_this --ignore-paths or_this -q)
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
        Gen.Mod.run(~w(some/namespace/new_module -t -q))

        assert_file("lib/some/namespace/new_module.html.leex", fn file ->
          assert file =~ "<!-- Some.Namespace.NewModule -->"
        end)
      end)
    end
  end

  describe "phoenix" do
    test "does not add standard ignore paths to namespace", config do
      in_tmp_phx_project(config.test, fn ->
        Gen.Mod.run(~w(elixir_mo_gen_web/controllers/new_controller -q))

        assert_file("lib/elixir_mo_gen_web/controllers/new_controller.ex", fn file ->
          assert file =~ "defmodule ElixirMoGenWeb.NewController do"
        end)

        assert_file("test/elixir_mo_gen_web/controllers/new_controller_test.exs", fn file ->
          assert file =~ "defmodule ElixirMoGenWeb.NewControllerTest do"
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
        assert output =~ ~S/code: flunk("no tests for #{Some.Namespace.NewModule} yet!")/
        assert output =~ "1 test, 1 failure"
      end)
    end
  end
end
