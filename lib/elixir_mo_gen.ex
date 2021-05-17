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

  def inflect(path, ignore_paths, mix_task \\ false) do
    parts =
      path
      |> String.split("/")
      |> ensure_lib_in_path
      |> maybe_ensure_mix_tasks_in_path(mix_task)

    namespace_parts = Enum.slice(parts, 1..-2)
    lib_dir = Path.join(Enum.slice(parts, 0..-2))
    app_name = List.last(parts)
    module_filename = app_name <> ".ex"
    test_app_name = app_name <> "_test"
    module_path = Path.join(lib_dir, module_filename)

    test_root = "test"
    test_dir = Path.join([test_root] ++ namespace_parts)
    test_filename = List.last(parts) <> "_test.exs"
    test_path = Path.join(test_dir, test_filename)

    test_relative_root = String.duplicate("../", length(namespace_parts))

    module =
      parts
      |> Enum.slice(1..-1)
      |> path_parts_to_module(ignore_paths)

    module_name =
      parts
      |> Enum.slice(-1..-1)
      |> path_parts_to_module([])

    once_removed_alias = maybe_once_removed_alias?(module_name, namespace_parts)

    [
      namespace_parts: namespace_parts,
      module_path: module_path,
      test_root: test_root,
      test_path: test_path,
      module: module,
      module_name: module_name,
      test_relative_root: test_relative_root,
      once_removed_alias: once_removed_alias,
      test_app_name: test_app_name,
      app_name: app_name
    ]
  end

  def get_ignore_paths(paths, nil), do: get_ignore_paths(paths, phoenix_project?())
  def get_ignore_paths(nil, is_phoenix), do: get_ignore_paths([], is_phoenix)

  def get_ignore_paths(paths, is_phoenix) when is_list(paths) do
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

  def get_ignore_path(path, is_phoenix) when not is_list(path),
    do: get_ignore_paths([path], is_phoenix)

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

  defp maybe_ensure_mix_tasks_in_path(parts, mix_task) do
    cond do
      not mix_task or Enum.slice(parts, 1..2) == ~w(mix tasks) ->
        parts

      true ->
        ["lib", "mix", "tasks"] ++ Enum.slice(parts, 1..-1)
    end
  end

  defp path_parts_to_module(parts, ignore_paths) do
    parts
    |> Enum.reject(fn part -> Enum.member?(ignore_paths, part) end)
    |> Enum.map(fn part -> camelize_path_part(part) end)
    |> Module.concat()
  end

  defp camelize_path_part(part) do
    part
    |> String.split(".")
    |> Enum.map(&ElixirMoGen.Naming.camelize/1)
    |> Enum.join(".")
  end

  def maybe_once_removed_alias?(module_name, namespace_parts) do
    cond do
      String.contains?(inspect(module_name), ".") ->
        name_parts =
          module_name
          |> inspect()
          |> String.split(".")

        {alias_parts, use_parts} = Enum.split(name_parts, length(name_parts) - 1)

        %{
          alias: path_parts_to_module(namespace_parts ++ alias_parts, []),
          use: path_parts_to_module(Enum.slice(alias_parts, -1..-1) ++ use_parts, [])
        }

      true ->
        %{alias: module_name, use: module_name}
    end
  end

  def copy_from(apps, source_dir, binding, mapping, opts \\ []) when is_list(mapping) do
    for {format, file_path, target} <- mapping do
      source =
        source_file_path(apps, source_dir, file_path) ||
          raise "could not find #{file_path} in any of the sources"

      case format do
        :text ->
          Mix.Generator.create_file(target, File.read!(source))

        :eex ->
          Mix.Generator.create_file(target, EEx.eval_file(source, binding), opts)

        :new_eex ->
          if File.exists?(target) do
            :ok
          else
            Mix.Generator.create_file(target, EEx.eval_file(source, binding), opts)
          end
      end
    end
  end

  defp source_file_path(apps, source_dir, file_path) do
    roots = Enum.map(apps, &to_app_source(&1, source_dir))

    Enum.find_value(roots, fn root ->
      source = Path.join(root, file_path)
      if File.exists?(source), do: source
    end)
  end

  def clean_from(mapping, opts \\ []) do
    for {_format, _source_file_path, target} <- mapping do
      if unchanged_or_force_or_ask?(target, opts) do
        File.rm!(target)
      end
    end
  end

  def unchanged_or_force_or_ask?(path, opts \\ []) do
    full = Path.expand(path)

    case age_in_seconds(path) do
      0 ->
        true

      {:error, "can't find file"} ->
        log(:yellow, "could not find", Path.relative_to_cwd(full), opts)
        false

      {:error, _msg} ->
        ask_unless_force(
          Path.relative_to_cwd(full),
          "Unable to determine if " <>
            Path.relative_to_cwd(full) <> " was modified after generation",
          "Delete anyway?",
          "Deleted",
          opts
        )

      _ ->
        ask_unless_force(
          Path.relative_to_cwd(full),
          Path.relative_to_cwd(full) <> " was modified after generation",
          "Delete anyway?",
          "Deleted",
          opts
        )
    end
  end

  def ask_unless_force(path, info, question, verb, opts) do
    if opts[:force] do
      unless opts[:quiet] do
        log(:red, verb, path, opts)
      end

      true
    else
      Mix.shell().yes?(format_ansi([info, :yellow, question, :reset]))
    end
  end

  defp format_ansi(message) do
    message |> IO.ANSI.format(false) |> IO.iodata_to_binary()
  end

  def print_version_banner(task, opts) do
    unless opts[:quiet] do
      text = purple(" ++ Elixir Mo' Gen v#{@version} ++ " <> dark_symbol(" #{task} "))

      IO.puts(text)
    end
  end

  defp purple(text) do
    IO.ANSI.color_background(53) <> IO.ANSI.color(97) <> text <> IO.ANSI.reset()
  end

  defp dark_symbol(text) do
    IO.ANSI.color_background(16) <> IO.ANSI.color(238) <> text <> IO.ANSI.reset()
  end

  # copied from https://github.com/elixir-lang/elixir/blob/master/lib/mix/lib/mix/generator.ex
  def log(color, command, message, opts) do
    unless opts[:quiet] do
      Mix.shell().info([color, "* #{command} ", :reset, message])
    end
  end

  defp to_app_source(path, source_dir) when is_binary(path),
    do: Path.join(path, source_dir)

  defp to_app_source(app, source_dir) when is_atom(app),
    do: Application.app_dir(app, source_dir)

  def age_in_seconds(path) do
    with created when is_integer(created) <- birth_time(path),
         modified when is_integer(modified) <- mod_time(path) do
      created - modified
    end
  end

  def birth_time(path) do
    if File.exists?(path) do
      case :os.type() do
        {:unix, :darwin} ->
          {result, 0} = System.cmd("stat", ["-f%B", path])

          result
          |> String.trim()
          |> String.to_integer()

        other ->
          {:error, "can't get file birth time on #{inspect(other)}"}
      end
    else
      {:error, "can't find file"}
    end
  end

  def mod_time(path) do
    if File.exists?(path) do
      {result, 0} = System.cmd("stat", ["-f%m", path])

      result
      |> String.trim()
      |> String.to_integer()
    else
      {:error, "can't find file"}
    end
  end
end
