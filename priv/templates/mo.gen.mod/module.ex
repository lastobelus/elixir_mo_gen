defmodule <%= inspect module %> do
  @moduledoc """
  Document <%= inspect module %> here.
  """
<%= if use_statements do %> <%= Enum.join(use_statements, "\n") %><% end %>
end
