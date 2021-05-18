defmodule Mix.Tasks.Mo.Gen.Mod do
  @moduledoc """
  Creates a new Elixir module and associated test file.

  It expects the lib-local path of the module as an argument(s):

      mix mo.gen.mod some/namespace/new_module

  It can create multiple modules/tests:

      mix mo.gen.mod first/module second/module

  When used in a Phoenix app (detected by inspecting mix.exs deps function
  for a reference to `:phoenix`, or by passing --phoenix or --no-phoenix)
  it will omit standard phoenix ignored paths (controllers, channels, views)
  from the fully-qualified module name.

  You can also pass your own paths to ignore in module names with one or more
  `--template some_path` options, or in your app config/dev.exs:

     config :mo_gen, ignore_paths: ~w(some paths_to_ignore)
  """

  use Mix.Task

  @shortdoc "Creates a new Elixir module and associated test file."

  @switches [
    ignore_paths: [:string, :keep],
    phoenix: :boolean,
    quiet: :boolean,
    template: :boolean,
    use: [:string],
    show_inflection: :boolean
  ]

  @aliases [
    i: :ignore_paths,
    q: :quiet,
    p: :phoenix,
    t: :template,
    u: :use
  ]
  @doc false
  @impl true
  def run([version]) when version in ~w(-v --version) do
    ElixirMoGen.print_version_banner("mo.gen.mod", [])
  end

  def run(args) do
    Mix.Task.run("app.start", ~w(--no-start))

    {opts, modules} = parse_opts!(args)

    quiet = Keyword.get(opts, :quiet)
    ElixirMoGen.print_version_banner("mo.gen.mod", quiet: quiet)

    is_phoenix = Keyword.get(opts, :phoenix, nil)

    ignore_paths =
      opts
      |> Keyword.get(:ignore_paths)
      |> ElixirMoGen.get_ignore_paths(is_phoenix)

    if opts[:show_inflection] do
      Enum.each(modules, fn module -> print_inflection(module, ignore_paths) end)
    else
      Enum.each(modules, fn module -> generate_module(module, ignore_paths, opts) end)
    end
  end

  defp parse_opts!(args) do
    {opts, modules} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    ignore_paths =
      opts
      |> Keyword.get_values(:ignore_paths)
      |> Enum.reduce([], fn p, paths -> paths ++ String.split(p, ",") end)

    opts = Keyword.replace(opts, :ignore_paths, ignore_paths)

    {opts, modules}
  end

  defp generate_module(module, ignore_paths, opts) do
    assigns =
      module
      |> ElixirMoGen.inflect(ignore_paths)
      |> Keyword.put(:use_statements, [])

    paths = ElixirMoGen.generator_paths()

    files =
      [
        {:eex, "module.ex", assigns[:module_path]},
        {:eex, "test.exs", assigns[:test_path]}
      ] ++ template_files(assigns, opts[:template])

    ElixirMoGen.copy_from(paths, "priv/templates/mo.gen.mod", assigns, files)
  end

  defp print_inflection(module, ignore_paths) do
    inflection =
      module
      |> ElixirMoGen.inflect(ignore_paths)

    IO.puts("inflection for #{module}:\n#{inspect(inflection, pretty: true)}\n\n")
  end

  defp template_files(_assigns, false), do: []
  defp template_files(_assigns, nil), do: []

  defp template_files(assigns, true) do
    [{:new_eex, "template.html.leex", assigns[:template_path]}]
  end
end
