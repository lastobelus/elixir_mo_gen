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
    prefix: :string,

    # column migrations
    comment: :string,
    default: :string,
    required: :boolean,
    null: :boolean,
    primary_key: :boolean,
    size: :integer,
    scale: :integer,
    precision: :integer,
    index: :boolean,

    # index migrations
    concurrently: :boolean,
    where: :string,
    include: :string,
    using: :string
  ]

  @aliases [
    q: :quiet,
    r: :repo,
    # for "namespace"
    n: :prefix,

    # column migrations
    c: :comment,
    d: :default,
    e: :required,
    k: :primary_key,

    # index migrations
    x: :concurrently,
    w: :where,
    i: :include,
    u: :using
  ]

  @default_opts [
    quiet: false,
    index: true
  ]

  @env_opts [
    prefix: "MO_GEN_MIGRATION_PREFIX",
    migrations_path: "MO_GEN_MIGRATION_PATH",
    quiet: "MO_GEN_MIGRATION_QUIET",
  ]

  @column_opts [
    :comment,
    :default,
    :required,
    :null,
    :primary_key,
    :size,
    :scale,
    :precision,
    :index
  ]

  @index_opts [
    :concurrently,
    :where,
    :include,
    :using
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

  @migration_cmds_usage %{
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
    # IO.inspect(args)
    {opts, args} = parse_opts!(args)
    quiet = Keyword.get(opts, :quiet)
    ElixirMoGen.print_version_banner("mo.gen.mod", quiet: quiet)

    try do
      Enum.each(
        [Mix.EctoCopy, ElixirMoGen.Column, ElixirMoGen.Migration.Column, ElixirMoGen.Naming],
        fn mod -> Code.ensure_loaded?(mod) end
      )

      Mix.Task.run("app.config")
      # Mix.Task.run("app.start", ~w(--no-start))
    rescue
      Mix.Error ->
        ElixirMoGen.warn(
          ~s{Mix.Task.run("app.config")},
          "unable to load app, some features may not be available",
          opts
        )
    end

    [migration_name | args] = args
    repos = Mix.EctoCopy.parse_repo(Keyword.get_values(opts, :repo))

    # IO.puts("opts: #{inspect(opts)}")
    # IO.puts("args: #{inspect(args)}")
    # IO.puts("migration_name: #{inspect(migration_name)}")
    # IO.puts("Migration.migration_module: #{inspect(Migration.migration_module())}")
    # IO.puts("repos: #{inspect(repos)}")

    Enum.map(repos, fn repo ->
      migration_name = Macro.underscore(migration_name)

      case parse_migration_type(migration_name) do
        nil ->
          raise_with_help("unable to interpret migration `#{migration_name}`", :unknown_cmd)

        {cmd, migration} ->
          # IO.puts("cmd: #{inspect(cmd)}")
          # IO.puts("migration: #{inspect(migration)}")

          migration =
            migration
            |> add_migration_opts(opts)
            |> add_cmd_opts(cmd, args, opts)
            |> setup_file_path(migration_name, repo)
            |> atomize_values([:table, :prefix])

          # IO.puts("running #{inspect(cmd)}")
          IO.inspect(migration, label: "migration")
          generate_migration(migration_name, repo, migration, cmd, args, opts)
      end
    end)
  end

  defp atomize_values(migration, keys) do
    Enum.reduce(keys, migration, fn k, acc ->
      cond do
        Map.has_key?(acc, k) ->
          Map.put(acc, k, String.to_atom(acc[k]))
        true -> acc
      end
    end)
  end

  defp parse_opts!(args) do
    {opts, parsed} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    merged_opts = opts_from_env()
    |> Keyword.merge(@default_opts)
    |> Keyword.merge(opts)

    {merged_opts, parsed}
  end

  defp opts_from_env do
    Enum.map(@env_opts, fn {opt, env} -> {opt, System.get_env(env)} end)
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
    cmds = Map.keys(@migration_cmds_usage)

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
    [first | rest] = @migration_cmds_usage[cmd]
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
        result -> {cmd, to_atom_keys(result)}
      end
    end)
  end

  defp to_atom_keys(map) do
    for {key, val} <- map, into: %{}, do: {String.to_atom(key), val}
  end

  def add_migration_opts(migration, opts) do
    Enum.into(Keyword.take(opts, [:comment, :prefix]), migration)
  end

  defp add_cmd_opts(migration, :add_column, args, opts) do
    case length(args) do
      0 ->
        columns = Column.single_column_from_migration(migration)

        migration
        |> add_columns(columns, opts)

      1 ->
        case Column.parse_single_column(List.first(args), migration[:column]) do
          {:ok, columns} ->
            migration
            |> add_columns(columns, opts)

          {:error, msg} ->
            raise_with_help(msg, :add_column)
        end

      _ ->
        raise_with_help("too many arguments for `add_COLUMN_to_TABLE`", :add_column)
    end
  end

  defp add_columns(migration, columns, opts) do
    Map.put(migration, :columns, add_column_opts(columns, opts))
  end

  defp add_column_opts(columns, opts) do
    column_opts = Keyword.take(opts, @column_opts)
    Enum.map(columns, fn {column, spec} ->
      {column, Enum.into(column_opts, spec)}
    end)
  end

  def maybe_run_migration?(file, repo) do
    if Mix.EctoCopy.open?(file) and Mix.shell().yes?("Do you want to run this migration?") do
      Mix.Task.run("ecto.migrate", ["-r", inspect(repo)])
    end
  end

  def setup_file_path(migration, name, repo) do
    # IO.puts("setup_file_path")
    # IO.inspect(migration, label: "migration")
    # IO.inspect(name, label: "name")
    # IO.inspect(repo, label: "repo")
    path =
      migration[:migrations_path] || Path.join(Mix.EctoCopy.source_repo_priv(repo), "migrations")

    base_name = "#{name}.exs"

    migration
    |> Map.put(:path, path)
    |> Map.put(:base_name, base_name)
  end

  def generate_migration(name, repo, migration, cmd, args, opts) do
    Mix.EctoCopy.ensure_repo(repo, args)
    path = opts[:migrations_path] || Path.join(Mix.EctoCopy.source_repo_priv(repo), "migrations")
    base_name = "#{ElixirMoGen.Naming.underscore(name)}.exs"
    file = Path.join(path, "#{timestamp()}_#{base_name}")
    unless File.dir?(path), do: create_directory(path)

    fuzzy_path = Path.join(path, "*_#{base_name}")

    if Path.wildcard(fuzzy_path) != [] do
      Mix.raise(
        "migration can't be created, there is already a migration file with name #{name}."
      )
    end

    assigns = [
      mod: Module.concat([repo, Migrations, ElixirMoGen.Naming.camelize(name)]),
      migration: add_changes(migration, cmd)
    ]

    create_file(file, migration_template(assigns))

    maybe_run_migration?(file, repo)

    file
  end

  defp add_changes(migration, :add_column) do
    Map.put(migration, :change, Migration.add_columns_template(migration))
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  embed_template(:migration, """
  defmodule <%= inspect @mod %> do
    use <%= inspect Migration.migration_module() %>

    def change do
  <%= @migration.change %>  end
  end
  """)
end
