defmodule ElixirMoGen.Migration do
  import Mix.Generator

  def migration_module do
    case Application.get_env(:ecto_sql, :migration_module, Ecto.Migration) do
      migration_module when is_atom(migration_module) -> migration_module
      other -> Mix.raise("Expected :migration_module to be a module, got: #{inspect(other)}")
    end
  end

  def column_options_template(_column) do
    ""
  end

  # I want to be able to test this directly, at least as I'm developing
  def add_columns_template(assigns) do
    add_column_template(assigns)
  end

  embed_template(:add_column, """
  alter table(<%= @table %>) do<%= for {name, spec} <- @columns do %>
    add <%= inspect name %>, <%= inspect spec.type %><%= column_options_template(spec) %><% end %>
  end
  """)
end
