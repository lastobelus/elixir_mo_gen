defmodule ElixirMoGen do
  @moduledoc """
  Documentation for `ElixirMoGen`.
  """

  @phoenix_ignore_paths ~w(channels controllers live views)
  @version Mix.Project.config()[:version]

  def generator_paths do
    [".", :elixir_mo_gen]
  end

  def phoenix_project? do
    file = File.read!("mix.exs")

    Regex.match?(~r/defp deps .*\[.*\{ *:phoenix,/s, file)
  end

  def inflect(path), do: inflect(path, [])

  def inflect(path, ignore_paths) do
    parts =
      path
      |> String.split("/")
      |> ensure_lib_in_path

    namespace_parts = Enum.slice(parts, 1..-2)
    lib_dir = Path.join(Enum.slice(parts, 0..-2))
    module_filename = List.last(parts) <> ".ex"
    module_path = Path.join(lib_dir, module_filename)

    test_dir = Path.join(["test"] ++ namespace_parts)
    test_filename = List.last(parts) <> "_test.exs"
    test_path = Path.join(test_dir, test_filename)

    module =
      parts
      |> Enum.slice(1..-1)
      |> path_parts_to_module(ignore_paths)

    [
      module_path: module_path,
      test_path: test_path,
      module: module
    ]
  end

  def get_ignore_paths(paths, nil), do: get_ignore_paths(paths, phoenix_project?())

  def get_ignore_paths(paths, is_phoenix) do
    has_paths = !Enum.empty?(paths)

    config_ignore_paths() ++
      cond do
        has_paths ->
          paths

        is_phoenix ->
          @phoenix_ignore_paths

        true ->
          []
      end
  end

  defp config_ignore_paths() do
    configured_paths = Application.get_env(:mo_gen, :ignore_paths, [])

    cond do
      is_list(configured_paths) ->
        configured_paths

      is_binary(configured_paths) ->
        String.split(configured_paths, ~r/ *, */)

      true ->
        []
    end
  end

  defp ensure_lib_in_path(parts) do
    cond do
      List.first(parts) == "lib" ->
        parts

      true ->
        ["lib"] ++ parts
    end
  end

  defp path_parts_to_module(parts, ignore_paths) do
    parts
    |> Enum.reject(fn part -> Enum.member?(ignore_paths, part) end)
    |> Enum.map(fn part -> ElixirMoGen.Naming.camelize(part) end)
    |> Module.concat()
  end

  def copy_from(apps, source_dir, binding, mapping) when is_list(mapping) do
    roots = Enum.map(apps, &to_app_source(&1, source_dir))

    for {format, source_file_path, target} <- mapping do
      source =
        Enum.find_value(roots, fn root ->
          source = Path.join(root, source_file_path)
          if File.exists?(source), do: source
        end) || raise "could not find #{source_file_path} in any of the sources"

      case format do
        :text ->
          Mix.Generator.create_file(target, File.read!(source))

        :eex ->
          Mix.Generator.create_file(target, EEx.eval_file(source, binding))

        :new_eex ->
          if File.exists?(target) do
            :ok
          else
            Mix.Generator.create_file(target, EEx.eval_file(source, binding))
          end
      end
    end
  end

  def print_version_banner(task) do
    text = purple(" ++ Elixir Mo' Gen v#{@version} ++ " <> dark_symbol(" #{task} "))

    IO.puts(text)
  end

  defp purple(text) do
    IO.ANSI.color_background(53) <> IO.ANSI.color(97) <> text <> IO.ANSI.reset()
  end

  defp dark_symbol(text) do
    IO.ANSI.color_background(16) <> IO.ANSI.color(238) <> text <> IO.ANSI.reset()
  end

  defp to_app_source(path, source_dir) when is_binary(path),
    do: Path.join(path, source_dir)

  defp to_app_source(app, source_dir) when is_atom(app),
    do: Application.app_dir(app, source_dir)
end
