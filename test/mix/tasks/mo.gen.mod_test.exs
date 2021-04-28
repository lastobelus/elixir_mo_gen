Code.require_file("../../mix_helper.exs", __DIR__)

defmodule ElixirMoGenTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Mo.Gen

  setup do
    Mix.Task.clear()
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
