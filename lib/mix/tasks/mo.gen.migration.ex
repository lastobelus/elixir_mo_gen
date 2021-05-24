defmodule Mix.Tasks.Mo.Gen.Migration do
  @moduledoc """
  Document Mix.Tasks.Mo.Gen.Migration here.
  """

  use Mix.Task
  alias ElixirMoGen.Migration
  alias ElixirMoGen.Migration.Column
  import Mix.Generator

  @shortdoc "Ecto migration generator that understands short-forms like `add_price_to_products :float`"

  @version "0.0.1"

  # customize colors of the CLI title banner for your task
  @cli_theme_bg 240
  @cli_theme_fg 250

  # see https://hexdocs.pm/elixir/OptionParser.html#parse/2
  @switches [
    quiet: :boolean,
    migrations_path: :string,
    repo: [:string, :keep],
    comment: :string,
    prefix: :string,
    # column migrations
    default: :string,
    # inverse of null
    required: :boolean,
    primary_key: :boolean,
    size: :integer,
    scale: :integer,
    precision: :integer,
    # index migrations
    concurrently: :boolean,
    where: :string,
    include: :string,
    using: :string
  ]

  @aliases [
    q: :quiet,
    r: :repo,
    c: :comment,
    # for "namespace"
    n: :prefix,
    # column migrations
    r: :required,
    k: :primary_key,

    # index migrations
    x: :concurrently,
    w: :where,
    i: :include,
    u: :using
  ]

  @default_opts [
    quiet: false
  ]

  @migration_types %{
    add_column: ~r/^add_(?<column>(?(?!index).)*)_to_(?<table>.*s$)/,
    add_columns: ~r/^add_to_(?<table>.*s$)/,
    add_index: ~r/add_(?:(?<index_name>(?(?!index).)*)_)?index_to_(?<table>.*s$)/,
    add_unique_index: ~r/add_(?:(?<index_name>(?(?!index).)*)_)?unique_index_to_(?<table>.*s$)/,
    remove_column: ~r/^remove_(?<column>(?(?!index).)*)_from_(?<table>.*s$)/,
    remove_columns: ~r/^remove_from_(?<table>.*s$)/,
    remove_index: ~r/remove_(?:(?<index_name>(?(?!index).)*)_)?index_from_(?<table>.*s$)/
  }

  @migration_templates %{
    add_column: ["add_COLUMNNAME_to_TABLENAME :TYPE", "# type defaults to string if ommitted"],
    add_columns: ["add_to_TABLENAME COLUMNNAME:TYPE COLUMNNAME:TYPE"],
    add_index: ["add_OPTIONALINDEXNAME_index_to_TABLENAME [COLUMNONE,COLUMN2]"],
    add_unique_index: ["add_OPTIONALINDEXNAME_unique_index_to_TABLENAME"],
    remove_column: [
      "remove_COLUMNNAME_from_TABLENAME :OPTIONALTYPE",
      "# type required to make reversible"
    ],
    remove_columns: ["remove_from_TABLENAME COLUMNNAME:OPTIONALTYPE COLUMNNAME:OPTIONALTYPE"],
    remove_index: [
      "remove_OPTIONALINDEXNAME_index_from_TABLENAME [OPTIONAL,COLUMN,LIST]",
      "# column list is required if OPTIONALINDEXNAME not included"
    ]
  }

  @doc false
  @impl true
  def run([version]) when version in ~w(-v --version) do
    print_version_banner(quiet: false)
  end

  def run(args) do
    repos = Mix.Ecto.parse_repo(args)

    {opts, args} = parse_opts!(args)

    [migration_name | args] = args

    print_version_banner(opts)

    IO.puts("opts: #{inspect(opts)}")
    IO.puts("migration_name: #{inspect(migration_name)}")
    IO.puts("args: #{inspect(args)}")
    IO.puts("Migration.migration_module: #{inspect(Migration.migration_module())}")
    IO.puts("repos: #{inspect(repos)}")

    case parse_migration_type(migration_name) do
      nil ->
        raise_with_help("unable to interpret migration `#{migration_name}`", :unknown_cmd)

      {cmd, migration} ->
        migration = add_opts_from_args(cmd, migration, args)
        IO.puts("running #{inspect(cmd)} with opts #{inspect(migration)}")
    end
  end

  defp parse_opts!(args) do
    {opts, parsed} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    merged_opts = Keyword.merge(@default_opts, opts)

    {merged_opts, parsed}
  end

  def raise_with_help(msg) do
    raise_with_help(msg, :general)
  end

  def raise_with_help(msg, :general) do
    Mix.raise("""
    #{msg}

    mix mo.gen.migration expects a migration name, followed by any arguments
    necessary to perform the command implied by the migration_name.

    For example, the following are equivalent, and generate a migration that
    adds a `size` column that is a string to the `products` table:

        mix mo.gen.migration add_size_to_products :string
        mix mo.gen.migration add_to_products size:string

    """)
  end

  def raise_with_help(msg, :unknown_cmd) do
    Mix.raise("""
    #{msg}

    mix mo.gen.migration expects a migration name, followed by any arguments
    necessary to perform the command implied by the migration_name.

    The type of migration and required arguments depends on the form of the
    migration name:

    #{migration_help("    ")}

    """)
  end

  def raise_with_help(msg, cmd) do
    Mix.raise("""
    #{msg}

    `#{to_string(cmd)}` migrations have the following form:

    #{migration_help(cmd, "    ")}

    """)
  end

  def migration_help(indent) do
    cmds = Map.keys(@migration_templates)

    cmd_indent_size =
      cmds
      |> Enum.map(&Kernel.to_string/1)
      |> Enum.max_by(&String.length/1)
      |> String.length()

    Enum.join(
      Enum.map(cmds, fn cmd -> migration_help(cmd, indent, cmd_indent_size + 3) end),
      "\n\n"
    )
  end

  def migration_help(cmd, indent) do
    migration_help(cmd, indent, String.length(to_string(cmd)) + 3)
  end

  def migration_help(cmd, indent, cmd_indent_size) do
    IO.puts("cmd: #{inspect(cmd)}")
    [first | rest] = @migration_templates[cmd]
    name = to_string(cmd)

    first_line = indent <> String.pad_trailing(to_string(name) <> ":", cmd_indent_size) <> first

    rest_lines = Enum.map(rest, fn s -> indent <> String.duplicate(" ", cmd_indent_size) <> s end)

    Enum.join(
      [first_line] ++ rest_lines,
      "\n"
    )
  end

  defp print_version_banner(opts) do
    unless opts[:quiet] do
      text = theme(" Mo.Gen.Migration  v#{@version} ")
      IO.puts(text)
    end
  end

  defp theme(text) do
    IO.ANSI.color_background(@cli_theme_bg) <>
      IO.ANSI.color(@cli_theme_fg) <> text <> IO.ANSI.reset()
  end

  def parse_migration_type(migration_name) do
    Enum.find_value(@migration_types, fn {cmd, regex} ->
      case Regex.named_captures(regex, migration_name) do
        nil -> false
        result -> {cmd, result}
      end
    end)
  end

  def add_opts_from_args(:add_column, migration, args) do
    if length(args) > 1 do
      raise_with_help("too many arguments for `add_COLUMN_to_TABLE`", :add_column)
    end

    case Column.parse_single_column(List.first(args), migration["column"], migration) do
      {:ok, columns} -> Map.put(migration, :columns, columns)
      {:error, msg} -> raise_with_help(msg, :add_column)
    end
  end

  def maybe_run_migration?(file, repo) do
    if Mix.Ecto.open?(file) and Mix.shell().yes?("Do you want to run this migration?") do
      Mix.Task.run("ecto.migrate", ["-r", inspect(repo)])
    end
  end

  embed_template(:migration, """
  defmodule <%= inspect @mod %> do
    use <%= inspect Migration.migration_module() %>

    def change do
  <%= @change %>
    end
  end
  """)
end
