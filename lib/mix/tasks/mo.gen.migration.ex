defmodule Mix.Tasks.Mo.Gen.Migration do
  @moduledoc """
  Document Mix.Tasks.Mo.Gen.Migration here.
  """

  use Mix.Task

  @shortdoc "Ecto migration generator that understands short-forms like `add_price_to_products :float`"

  @version "0.0.1"

  # customize colors of the CLI title banner for your task
  @cli_theme_bg 240
  @cli_theme_fg 250

  # see https://hexdocs.pm/elixir/OptionParser.html#parse/2
  @switches [quiet: :boolean]

  @default_opts [quiet: false]

  @migration_types %{
    add_column: ~r/^add_(?<column>(?(?!index).)*)_to_(?<table>.*s$)/,
    add_columns: ~r/^add_to_(?<table>.*s$)/,
    add_index: ~r/add_(?:(?<index_name>(?(?!index).)*)_)?index_to_(?<table>.*s$)/,
    add_unique_index: ~r/add_(?:(?<index_name>(?(?!index).)*)_)?unique_index_to_(?<table>.*s$)/,
    remove_column: ~r/^remove_(?<column>(?(?!index).)*)_from_(?<table>.*s$)/,
    remove_columns: ~r/^remove_from_(?<table>.*s$)/,
    remove_index: ~r/remove_(?:(?<index_name>(?(?!index).)*)_)?index_from_(?<table>.*s$)/
  }
  @doc false
  @impl true
  def run([version]) when version in ~w(-v --version) do
    print_version_banner(quiet: false)
  end

  def run(args) do
    {opts, args} = parse_opts!(args)

    print_version_banner(opts)

    IO.puts("opts: #{inspect(opts)}")
    IO.puts("args: #{inspect(args)}")

    # to extract single options (ex: `@switches [name: :string]`)
    # `Keyword.get(opts, :name)`
    #
    # to extract array options (ex: `@switches [paths: [:string, :keep]]`)
    # `Keyword.get_values(:paths)`
  end

  defp parse_opts!(args) do
    {opts, parsed} = OptionParser.parse!(args, strict: @switches, aliases: [q: :quiet])

    merged_opts = Keyword.merge(@default_opts, opts)

    {merged_opts, parsed}
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
end
