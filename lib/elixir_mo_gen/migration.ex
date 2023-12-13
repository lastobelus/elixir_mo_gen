defmodule ElixirMoGen.Migration do
@moduledoc """
This module provides functions for generating migrations.
"""

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

    maybe_add_options(spec)
    |> maybe_add_comment(comment)
  end

  defp maybe_add_options(spec) when map_size(spec) == 0 do
    ""
  end
  defp maybe_add_options(spec) do
    ", " <> to_opts(spec)
  end

  def maybe_add_comment(s, nil), do: s
  def maybe_add_comment(s, comment), do: s <> "   # #{comment}"

  defp to_opts(spec) do
    Enum.map_join(spec, ", ", fn {k, v} ->
      "#{k}: #{v}"
    end)
  end

  # I want to be able to test this directly, at least as I'm developing
  def add_columns_template(migration) do
    add_column_template(migration: migration)
  end

  defp has_index?(migration) do
    Enum.any?(migration.columns, fn {_n, spec} -> Map.get(spec, :index, true) end)
  end

  defp maybe_prefix?(migration) do
    if Map.has_key?(migration, :prefix) do
      ", prefix: #{inspect(migration.prefix)}"
    else
      ""
    end
  end

  defp normalize_type(type) when is_atom(type) do
    inspect(type)
  end

  defp normalize_type(type) do
    type
  end

  embed_template(:add_column, """
      alter table(<%= inspect @migration.table %><%= maybe_prefix?(@migration) %>) do<%= for {name, spec} <- @migration.columns do %>
        add <%= inspect name %>, <%= normalize_type(spec.type) %><%= column_options_template(spec) %><% end %>
      end<%= if has_index?(@migration) do %><%= indexes_template(migration: @migration) %><% end %>
  """)

  embed_template(:indexes, """

  <%= for {name, spec} <- @migration.columns do %><%= if spec.index do %>
      create index(<%= inspect @migration.table %>, [<%= inspect name %>]<%= maybe_prefix?(@migration) %>)<% end %><% end %>\
  """)
end
