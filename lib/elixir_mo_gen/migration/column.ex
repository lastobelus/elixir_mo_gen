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
    ref: :references,
    bool: :boolean,
    utc: :utc_datetime
  }

  @column_switches [
    :unique,
    :index,
    :null,
    :primary_key
  ]

  @index_switches [
    :unique,
    :index,
    :null,
    :primary_key
  ]

  @column_switches_aliases %{
    u: :unique,
    uniq: :unique,
    pk: :primary_key,
    ix: :index
  }
  def parse_single_column(arg, name) do
    [column | opts] = String.split(arg, ":")

    name = name && String.trim(name)
    column = least_blank(String.trim(column), name) |> Macro.underscore()

    cond do
      blank?(column) ->
        {:error, "column name is missing"}

      true ->
        parse_column(column, opts)
    end
  end

  def single_column_from_migration(migration) do
    %{String.to_atom(migration[:column]) => %{type: :string}}
  end

  def parse_column(column, []) do
    parse_column(column, ["string"])
  end

  def parse_column(column, opts) do
    [type | args] = opts

    {args, spec} =
      case validate_type(type) do
        {true, type} ->
          {args, %{type: type}}

        {false, _} ->
          {opts, %{type: :string}}
      end

    try do
        spec = Enum.reduce(args, spec, fn arg, acc ->
          [arg|value] = String.split(arg, "{")
          value = List.last(value) || ""
          arg_spec = opt_to_arg(arg, String.trim(value, "}"))
          Map.merge(acc, arg_spec)
        end)
        {:ok, %{String.to_atom(column) => spec}}
    rescue
      e ->
        {:error, "#{e.message} for column `#{column}`"}
    end
  end

  def validate_type(arg) do
    type = string_to_atom(arg)
    type = Map.get(@type_aliases, type, type)

    if Enum.member?(@column_types, type) do
      {true, type}
    else
      {false, arg}
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

  defp opt_to_arg("decimal", val) do
    cond do
      blank?(val) ->
        %{type: :decimal}

      String.contains?(val, ",") ->
        [precision, scale] = String.split(val, ",")
        %{type: :decimal, precision: precision, scale: scale}

      true ->
        raise "invalid decimal format: `#{val}`"
    end
  end

  defp opt_to_arg("references", table), do: %{type: "references(:#{table})"}

  defp opt_to_arg("string", size), do: %{type: :string, size: size}
  defp opt_to_arg("s", size), do: %{type: :string, size: size}
  defp opt_to_arg("default", value), do: %{default: value}
  defp opt_to_arg("comment", value), do: %{comment: value}
  defp opt_to_arg("c", value), do: %{comment: value}

  defp opt_to_arg(opt, _) do
    [switch | val] = Enum.reverse(String.split(opt, "no-"))
    switch = string_to_atom(switch)
    switch = Map.get(@column_switches_aliases, switch, switch)
    val = Enum.empty?(val)

    case Enum.member?(@column_switches, switch) do
      true ->
        [{switch, val}] |> Map.new()

      false ->
        raise "invalid option/type `#{opt}`"
    end
  end
end
