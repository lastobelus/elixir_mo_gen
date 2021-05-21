Code.require_file("../../mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Mo.Gen.MigrationTest do
  @moduledoc false
  
  use ExUnit.Case
  import MixHelper
  import ExUnit.CaptureIO

  alias Mix.Tasks.Mo.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  describe "options" do
    test "it prints the version", config do
      in_tmp_project(config.test, fn ->
        assert capture_io(fn ->
          Gen.Migration.run(~w(-v))
        end) =~ "Mo.Gen.Migration  v0.0.1"
      end)
    end
  end

  # Example of testing generated file
  #
  # test "generates foo/bar", config do
  #   in_tmp_project(config.test, fn ->
  #     Gen.Migration.run(~w(foo_bar -q))

  #     assert_file("lib/foo.bar.ex", fn file ->
  #       assert file =~ "defmodule Foo.Bar do"
  #     end)

  #   end)
  # end

end
