defmodule Mix.Tasks.Mo.Gen.Mod do
  @moduledoc """
  Creates a new Elixir module and associated test file.

  It expects the lib-local path of the module as an argument(s):

      mix mo.gen.mod some/namespace/new_module

  ...will create `lib/my_app/some/namespace/new_module.ex`.

  To create a module outside of the app namespace, prefix the path with a `/`:

      mix mo.gen.mod /some/namespace/new_module

  will create `lib/some/namespace/new_module.ex`.

  It will also understand PascalCase module names, but don't mix with underscore or `/`:

      mix mo.gen.mod Some.NewModule

  will create `lib/my_app/some/new_module.ex`.

  It can handle names with `.` in them, when supplied in path/underscore form:

      mix mo.gen.mod some/module.with.dot

  will create `lib/my_app/some/module.with.dot.ex`, and the module name will be "MyApp.Some.ModuleWithDot".
  This feature is used by `mix mo.gen.gen`.

  It can create multiple modules/tests:

      mix mo.gen.mod first/module second/module

  ## Phoenix Apps

  When used in a Phoenix app (detected by inspecting mix.exs deps function
  for a reference to `:phoenix`, or by passing `--phoenix`/`-p`)
  it will omit standard phoenix ignored paths (controllers, channels, views)
  from the fully-qualified module name.

  You can also use `web` as an alias for `my_app_web` in phoenix apps:

      mix mo.gen.mod web/controllers/new_controller

  will  create `lib/my_app_web/controllers/new_controller.ex`, with the module
  name `MyAppWeb.NewController`

  You can indicate a web use macro by appending it with colon. The following aliases
  are recognized:

      "ch" => "channel",
      "c" => "controller",
      "lc" => "live_component",
      "lv" => "live_view",
      "r" => "router",
      "v" => "view",
      "sv" => "surface_view",
      "sc" => "surface_component"

  For example:

      mix mo.gen.mod web/controllers/new_controller:c

  will  create `lib/my_app_web/controllers/new_controller.ex`, with the module
  name `MyAppWeb.NewController`, and add the line `use MyAppWeb, :controller`


  ## Configurable Ignore Paths

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

    quiet = Keyword.get(opts, :quiet)
    ElixirMoGen.print_version_banner("mo.gen.mod", quiet: quiet)

    is_phoenix = Keyword.get(opts, :phoenix, nil)

    try do
      Mix.Task.run("app.config")
      # Mix.Task.run("app.start", ~w(--no-start))
    rescue
      Mix.Error ->
        ElixirMoGen.warn(
          # ~s{Mix.Task.run("app.start", ~w(--no-start))},
          ~s{Mix.Task.run("app.config")},
          "unable to load app, some features may not be available",
          opts
        )
    end

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
          maybe_warn_about_web_module(module, use_alias, opts)
        end

        {module_name, use_alias}

      _ ->
        raise "`#{module}` -- can only add one use macro"
    end
  end

  def maybe_warn_about_web_module(module, use_alias, opts) do
    {result, msg} = ElixirMoGen.phoenix_web_macros()

    if result == :error do
      ElixirMoGen.warn("#{module}", "#{msg} using `#{use_alias}`", opts)
    end
  end
end
