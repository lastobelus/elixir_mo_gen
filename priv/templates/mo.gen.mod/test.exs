defmodule <%= inspect module %>Test do
  @moduledoc false
<%= if use_statements do %>  <%= Enum.join(use_statements, "\n") %><% else %>
  use ExUnit.Case<% end %>
  alias <%= inspect module %>

  describe "<%= inspect module %>" do
    test "write some tests" do
      flunk("no tests for #{<%= inspect module %>} yet!")
    end
  end
end
