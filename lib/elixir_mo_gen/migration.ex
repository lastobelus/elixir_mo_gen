defmodule ElixirMoGen.Migration do
  import Mix.Generator

  def migration_module do
    case Application.get_env(:ecto_sql, :migration_module, Ecto.Migration) do
      migration_module when is_atom(migration_module) -> migration_module
      other -> Mix.raise("Expected :migration_module to be a module, got: #{inspect(other)}")
    end
  end


  def column_options_template(spec) do
    {comment, spec} = Map.pop(spec, :comment)
    {_, spec} = Map.split(spec, [:type, :index])

    s =
      cond do
        Enum.empty?(spec) -> ""
        true -> ", " <> to_opts(spec)
      end

    cond do
      comment -> s <> "   # #{comment}"
      true -> s
    end
  end

  defp to_opts(spec) do
    Enum.join(
      Enum.map(spec, fn {k, v} ->
        "#{k}: #{v}"
      end),
      ", "
    )
  end

  # I want to be able to test this directly, at least as I'm developing
  def add_columns_template(migration) do
    add_column_template(migration: migration)
  end

  defp has_index?(migration) do
    Enum.any?(migration.columns, fn {_n, spec} -> Map.get(spec, :index, true) end)
  end

  defp maybe_prefix?(migration) do
    cond do
      Map.has_key?(migration, :prefix) ->
        ", prefix: #{inspect(migration.prefix)}"
      true -> ""
    end
  end

  embed_template(:add_column, """
      alter table(<%= inspect @migration.table %><%= maybe_prefix?(@migration) %>) do<%= for {name, spec} <- @migration.columns do %>
        add <%= inspect name %>, <%= inspect spec.type %><%= column_options_template(spec) %><% end %>
      end<%= if has_index?(@migration) do %><%= indexes_template(migration: @migration) %><% end %>
  """)


  embed_template(:indexes, """

  <%= for {name, spec} <- @migration.columns do %><%= if spec.index do %>
      create index(<%= inspect @migration.table %>, [<%= inspect name %>]<%= maybe_prefix?(@migration) %>)<% end %><% end %>\
  """)

end
