defmodule ElixirMoGen.Migration.Column do
  @column_types [
    :integer,
    :float,
    :decimal,
    :boolean,
    :map,
    :string,
    :array,
    :references,
    :text,
    :date,
    :time,
    :time_usec,
    :naive_datetime,
    :naive_datetime_usec,
    :utc_datetime,
    :utc_datetime_usec,
    :uuid,
    :binary,
    :datetime
  ]

  @type_aliases %{
    i: :integer,
    f: :float,
    s: :string,
    t: :text,
    bool: :boolean,
    utc: :utc_datetime
  }

  def parse_single_column(arg, name, migration) do
    [column | opts] = String.split(arg, ":")

    name = String.trim(name)
    column = least_blank(String.trim(column), name)

    cond do
      blank?(column) ->
        {:error, "column name is missing"}

      column != name ->
        {:error, "column `#{name}` parsed from migration name does not match `#{column}`"}

      true ->
        parse_column(column, opts, migration)
    end
  end

  def parse_column(column, [], _migration) do
    %{column => %{type: :string}}
  end

  def parse_column(column, [type], _migration) do
    case validate_type(type) do
      nil ->
        {:error, "invalid type `#{type}` for column `#{column}`"}

      type ->
        {:ok, %{column => %{type: type}}}
    end
  end

  def validate_type(type) do
    type = string_to_atom(type)
    type = Map.get(@type_aliases, type, type)

    if Enum.member?(@column_types, type) do
      type
    else
      nil
    end
  end

  defp least_blank(a, b) do
    cond do
      blank?(a) -> String.trim(b)
      true -> String.trim(a)
    end
  end

  defp blank?(str_or_nil),
    do: "" == str_or_nil |> to_string() |> String.trim()

  defp string_to_atom(str) do
    try do
      String.to_existing_atom(str)
    rescue
      ArgumentError -> nil
    end
  end
end
