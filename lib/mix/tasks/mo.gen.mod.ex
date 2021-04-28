defmodule Mix.Tasks.Mo.Gen.Mod do
  @moduledoc false

  use Mix.Task

  @switches [ignore_paths: [:string, :keep]]
  @doc false
  def run(args) do
    IO.puts("args: #{inspect(args)}")

    {ignore_paths, modules} = parse_opts!(args)

    ignore_paths = ElixirMoGen.get_ignore_paths(ignore_paths)
    IO.puts("ignore_paths: #{inspect(ignore_paths)}")

    Enum.each(modules, fn module -> generate_module(module, ignore_paths) end)
  end

  defp parse_opts!(args) do
    IO.puts("args: #{inspect(args)}")
    {opts, modules} = OptionParser.parse!(args, strict: @switches, aliases: [i: :ignore_paths])

    ignore_paths =
      opts
      |> Keyword.get_values(:ignore_paths)
      |> Enum.reduce([], fn p, paths -> paths ++ String.split(p, ",") end)

    {ignore_paths, modules}
  end

  defp generate_module(module, ignore_paths) do
    assigns =
      module
      |> ElixirMoGen.inflect(ignore_paths)
      |> IO.inspect(label: "assigns")
      |> Keyword.put(:use_statements, [])

    paths = ElixirMoGen.generator_paths()

    files = [
      {:eex, "module.ex", assigns[:module_path]},
      {:eex, "test.exs", assigns[:test_path]}
    ]

    ElixirMoGen.copy_from(paths, "priv/templates/mo.gen.mod", assigns, files)
  end
end
