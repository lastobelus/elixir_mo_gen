Code.require_file("../../mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Mo.Gen.GenTest do
  @moduledoc false

  use ExUnit.Case

  import MixHelper
  alias Mix.Tasks.Mo.Gen

  setup do
    Mix.Task.clear()
    Application.put_env(:mo_gen, :ignore_paths, nil)
    :ok
  end

  describe "Mix.Tasks.Mo.Gen.Gen" do
    @tag capture_log: true
    test "generates module and test file", config do
      in_tmp_project(config.test, fn ->
        Gen.Gen.run(~w(mix/tasks/my.gen.example -q))

        assert_file("lib/mix/tasks/my.gen.example.ex", fn file ->
          assert file =~ "defmodule Mix.Tasks.My.Gen.Example do"
        end)
      end)
    end

    test "handles omitting `mix/tasks`", config do
      in_tmp_project(config.test, fn ->
        Gen.Gen.run(~w(my.gen.example -q))

        assert_file("lib/mix/tasks/my.gen.example.ex", fn file ->
          assert file =~ "defmodule Mix.Tasks.My.Gen.Example do"
        end)
      end)
    end
  end
end
