Code.require_file("../../mix_helper.exs", __DIR__)

defmodule ElixirMoGenTest do
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
      Gen.Mod.run(~w(some/namespace/new_module))

      assert_file("lib/some/namespace/new_module.ex", fn file ->
        IO.puts("file:\n #{file}")
        assert file =~ "defmodule Some.Namespace.NewModule do"
      end)

      assert_file("test/some/namespace/new_module_test.exs", fn file ->
        IO.puts("file:\n #{file}")
        assert file =~ "defmodule Some.Namespace.NewModuleTest do"
      end)
    end)
  end

  describe "ignore_paths" do
    test "ignores paths configured in config()[:mo_gen][:ignore_paths]", config do
      Application.put_env(:mo_gen, :ignore_paths, "not_this")

      in_tmp_project(config.test, fn ->
        Gen.Mod.run(~w(some/namespace/not_this/new_module))

        assert_file("lib/some/namespace/not_this/new_module.ex", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModule do"
        end)

        assert_file("test/some/namespace/not_this/new_module_test.exs", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModuleTest do"
        end)
      end)

      Application.put_env(:mo_gen, :ignore_paths, ["not_this", "or_this"])

      in_tmp_project(config.test, fn ->
        Gen.Mod.run(~w(some/namespace/not_this/or_this/new_module))

        assert_file("lib/some/namespace/not_this/or_this/new_module.ex", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModule do"
        end)

        assert_file("test/some/namespace/not_this/or_this/new_module_test.exs", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModuleTest do"
        end)
      end)

      Application.put_env(:mo_gen, :ignore_paths, "not_this,or_this")

      in_tmp_project(config.test, fn ->
        Gen.Mod.run(~w(some/namespace/not_this/or_this/new_module))

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
          ~w(some/namespace/not_this/or_this/new_module --ignore_paths not_this --ignore_paths or_this)
        )

        assert_file("lib/some/namespace/not_this/or_this/new_module.ex", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModule do"
        end)

        assert_file("test/some/namespace/not_this/or_this/new_module_test.exs", fn file ->
          assert file =~ "defmodule Some.Namespace.NewModuleTest do"
        end)
      end)
    end
  end

  describe "phoenix" do
    test "does not add standard ignore paths to namespace", config do
      in_tmp_phx_project(config.test, fn ->
        Gen.Mod.run(~w(some/namespace/new_module))

        assert_file("lib/some/namespace/new_module.ex", fn file ->
          IO.puts("file:\n #{file}")
          assert file =~ "defmodule Some.Namespace.NewModule do"
        end)

        assert_file("test/some/namespace/new_module_test.exs", fn file ->
          IO.puts("file:\n #{file}")
          assert file =~ "defmodule Some.Namespace.NewModuleTest do"
        end)
      end)
    end
  end
end
