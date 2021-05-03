defmodule Mix.Tasks.Mo.Gen.Gen do
  @moduledoc """
  Bootstrap a new generator, with OptionParser and test.

  It expects the lib-local path of the generator module as an argument(s):

      mix mo.gen.mod mix/tasks/my.gen.widget

  It will add mix/tasks if omitted, so all of the following are equivalent:

      mix mo.gen.mod lib/mix/tasks/my.gen.widget
      mix mo.gen.mod mix/tasks/my.gen.widget
      mix mo.gen.mod my.gen.widget


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

  @switches [ignore_paths: [:string, :keep], phoenix: :boolean, quiet: :boolean, clean: :boolean]
  @doc false
  @impl true
  def run([version]) when version in ~w(-v --version) do
    ElixirMoGen.print_version_banner("mo.gen.mod", [])
  end

  def run(args) do
    {opts, modules} = parse_opts!(args)

    IO.puts("yo")
    IO.inspect(opts, label: "opts")
    IO.inspect(modules, label: "modules")

    ElixirMoGen.print_version_banner("mo.gen.mod", opts)

    ignore_paths = ElixirMoGen.get_ignore_paths(opts[:ignore_paths], opts[:phoenix])

    cond do
      opts[:clean] ->
        Enum.each(modules, fn module -> clean_module(module, ignore_paths, opts) end)

      true ->
        Enum.each(modules, fn module -> generate_module(module, ignore_paths, opts) end)
    end
  end

  defp parse_opts!(args) do
    {opts, modules} =
      OptionParser.parse!(args,
        strict: @switches,
        aliases: [i: :ignore_paths, q: :quiet, d: :clean]
      )

    ignore_paths =
      opts
      |> Keyword.get_values(:ignore_paths)
      |> Enum.reduce([], fn p, paths -> paths ++ String.split(p, ",") end)

    opts = Keyword.put(opts, :ignore_paths, ignore_paths)

    {opts, modules}
  end

  defp files(assigns) do
    [
      {:eex, "module.ex", assigns[:module_path]},
      {:eex, "test.exs", assigns[:test_path]},
      {:eex, "mix_helper.exs", Path.join([assigns[:test_root]], "mix_helper.exs")}
    ]
  end

  defp generate_module(module, ignore_paths, opts) do
    assigns =
      module
      |> ElixirMoGen.inflect(ignore_paths, true)
      |> IO.inspect(label: "inflected:")
      |> Keyword.put(:use_statements, [])

    paths = ElixirMoGen.generator_paths()

    ElixirMoGen.copy_from(paths, "priv/templates/mo.gen.gen", assigns, files(assigns), opts)
  end

  def clean_module(module, ignore_paths, opts) do
    assigns =
      module
      |> ElixirMoGen.inflect(ignore_paths, true)

    ElixirMoGen.clean_from(files(assigns), opts)
  end
end
