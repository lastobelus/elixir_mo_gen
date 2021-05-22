defmodule Mix.Tasks.Mo.Gen.Gen do
  @moduledoc """
  Bootstrap a new generator, with OptionParser and test.

  It expects the lib-local path of the generator module as an argument(s):

      mix mo.gen.gen mix/tasks/my.gen.widget

  It will add mix/tasks if omitted, so all of the following are equivalent:

      mix mo.gen.gen lib/mix/tasks/my.gen.widget
      mix mo.gen.gen mix/tasks/my.gen.widget
      mix mo.gen.gen my.gen.widget


  It can create multiple modules/tests:

      mix mo.gen.gen first/module second/module

  ## Options

  - `--quiet (-q)`: don't print banner or generator output
  - `--clean (-d)`: delete files this generator creates.
    On OS X it will ask if the file birth-time and modified-time are different, but
    if you said `No` to overwrite for that file it will potentially still be deleted.
  - `--version (-v)`: print the version


  """

  use Mix.Task

  @shortdoc "Creates a new Elixir module and associated test file."

  @switches [
    ignore_paths: [:string, :keep],
    phoenix: :boolean,
    quiet: :boolean,
    clean: :boolean
  ]

  @aliases [
    i: :ignore_paths,
    q: :quiet,
    d: :clean
  ]
  @doc false
  @impl true
  def run([version]) when version in ~w(-v --version) do
    ElixirMoGen.print_version_banner("mo.gen.gen", [])
  end

  def run(args) do
    {opts, modules} = parse_opts!(args)

    ElixirMoGen.print_version_banner("mo.gen.gen", opts)

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
        aliases: @aliases
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
