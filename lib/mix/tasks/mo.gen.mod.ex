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
    show_inflection: :boolean,
    force: :boolean
  ]

  @aliases [
    i: :ignore_paths,
    q: :quiet,
    p: :phoenix,
    t: :template,
    u: :use,
    f: :force
  ]

  @use_aliases %{
    "ch" => "channel",
    "c" => "controller",
    "lc" => "live_component",
    "lv" => "live_view",
    "r" => "router",
    "v" => "view",
    "sv" => "surface_view",
    "sc" => "surface_component"
  }

  @doc false
  @impl true
  def run([version]) when version in ~w(-v --version) do
    ElixirMoGen.print_version_banner("mo.gen.mod", [])
  end

  def run(args) do
    {opts, modules} = parse_opts!(args)

    try do
      Mix.Task.run("app.start", ~w(--no-start))
    rescue
      Mix.Error ->
        ElixirMoGen.warn(
          ~s{Mix.Task.run("app.start", ~w(--no-start))},
          "unable to load app, some features may not be available",
          opts
        )
    end

    quiet = Keyword.get(opts, :quiet)
    ElixirMoGen.print_version_banner("mo.gen.mod", quiet: quiet)

    is_phoenix = Keyword.get(opts, :phoenix, nil)

    ignore_paths =
      opts
      |> Keyword.get(:ignore_paths)
      |> ElixirMoGen.get_ignore_paths(is_phoenix)

    if opts[:show_inflection] do
      Enum.each(modules, fn module -> print_inflection(module, ignore_paths, opts) end)
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
    {module_name, use_macro} = parse_use_macro(module, opts)

    assigns =
      module_name
      |> ElixirMoGen.inflect(ignore_paths, false, use_macro)

    paths = ElixirMoGen.generator_paths()

    files =
      [
        {:eex, "module.ex", assigns[:module_path]},
        {:eex, "test.exs", assigns[:test_path]}
      ] ++ template_files(assigns, opts[:template])

    ElixirMoGen.copy_from(paths, "priv/templates/mo.gen.mod", assigns, files)
  end

  defp print_inflection(module, ignore_paths, opts) do
    {module_name, use_macro} = parse_use_macro(module, opts)

    IO.puts("module_name: #{inspect(module_name)}")
    IO.puts("use_macro: #{inspect(use_macro)}")

    inflection =
      module_name
      |> ElixirMoGen.inflect(ignore_paths, false, use_macro)

    IO.puts("inflection for #{module}:\n#{inspect(inflection, pretty: true)}\n\n")
  end

  defp template_files(_assigns, false), do: []
  defp template_files(_assigns, nil), do: []

  defp template_files(assigns, true) do
    [{:new_eex, "template.html.leex", assigns[:template_path]}]
  end

  defp parse_use_macro(module, opts) do
    [module_name | rest] = String.split(module, ":")

    case length(rest) do
      0 ->
        {module_name, nil}

      1 ->
        use_alias = List.first(rest)
        use_alias = Map.get(@use_aliases, use_alias, use_alias)

        if use_alias do
          case ElixirMoGen.phoenix_web_macros() do
            {:ok, _macros} ->
              {module_name, use_alias}

            {:error, msg} ->
              ElixirMoGen.warn("#{module}", "#{msg} using `#{use_alias}`", opts)
              {module_name, use_alias}
          end
        end

      _ ->
        raise "`#{module}` -- can only add one use macro"
    end
  end
end
