Code.require_file("<%= test_relative_root %>mix_helper.exs", __DIR__)

defmodule <%= inspect module %>Test do
  @moduledoc false
<%= if use_statements do %>  <%= Enum.join(use_statements, "\n") %><% else %><% end %>
  use ExUnit.Case
  import MixHelper
  import ExUnit.CaptureIO

  alias <%= inspect once_removed_alias[:alias] %>

  setup do
    Mix.Task.clear()
    :ok
  end

  describe "options" do
    test "it prints the version", config do
      in_tmp_project(config.test, fn ->
        assert capture_io(fn ->
          <%= inspect once_removed_alias[:use] %>.run(~w(-v))
        end) =~ "<%= inspect module_name %>  v0.0.1"
      end)
    end
  end

  # Example of testing generated file
  #
  # test "generates foo/bar", config do
  #   in_tmp_project(config.test, fn ->
  #     <%= inspect once_removed_alias[:use] %>.run(~w(foo_bar -q))

  #     assert_file("lib/foo.bar.ex", fn file ->
  #       assert file =~ "defmodule Foo.Bar do"
  #     end)

  #   end)
  # end

end
