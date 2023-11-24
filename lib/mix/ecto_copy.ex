defmodule Mix.EctoCopy do
  @moduledoc """
  Conveniences for writing Ecto related Mix tasks.
  """

  # region [ copied from https://github.com/elixir-ecto/ecto@lib/mix/ecto.ex ]

  @doc """
  Parses the repository option from the given command line args list.

  If no repo option is given, it is retrieved from the application environment.
  """
  def parse_repo(repos) do
    parse_repo(repos, [])
  end

  defp parse_repo([repo | t], acc)  do
    parse_repo(t, [Module.concat([repo]) | acc])
  end

  defp parse_repo([], []) do
    IO.puts("parse_repo")

    apps =
      if apps_paths = Mix.Project.apps_paths() do
        # TODO: Use the proper ordering from Mix.Project.deps_apps
        # when we depend on Elixir v1.11+.
        apps_paths |> Map.keys() |> Enum.sort()
      else
        [Mix.Project.config()[:app]]
      end

    dbg(apps)

    apps
    |> Enum.flat_map(fn app ->
      Application.load(app)
      Application.get_env(app, :ecto_repos, [])
    end)
    |> Enum.uniq()
    |> case do
      [] ->
        Mix.shell().error("""
        warning: could not find Ecto repos in any of the apps: #{inspect(apps)}.

        You can avoid this warning by passing the -r flag or by setting the
        repositories managed by those applications in your config/config.exs:

            config #{inspect(hd(apps))}, ecto_repos: [...]
        """)

        []

      repos ->
        repos
    end
  end

  defp parse_repo([], acc) do
    Enum.reverse(acc)
  end

  @doc """
  Ensures the given module is an Ecto.Repo.
  """
  def ensure_repo(repo, args) do
    # Do not pass the --force switch used by some tasks downstream
    args = List.delete(args, "--force")

    # TODO: Use only app.config when we depend on Elixir v1.11+.
    if Code.ensure_loaded?(Mix.Tasks.App.Config) do
      Mix.Task.run("app.config", args)
    else
      Mix.Task.run("loadpaths", args)
      "--no-compile" not in args && Mix.Task.run("compile", args)
    end

    case Code.ensure_compiled(repo) do
      {:module, _} ->
        if function_exported?(repo, :__adapter__, 0) do
          repo
        else
          Mix.raise(
            "Module #{inspect(repo)} is not an Ecto.Repo. " <>
              "Please configure your app accordingly or pass a repo with the -r option."
          )
        end

      {:error, error} ->
        Mix.raise(
          "Could not load #{inspect(repo)}, error: #{inspect(error)}. " <>
            "Please configure your app accordingly or pass a repo with the -r option."
        )
    end
  end

  @doc """
  Asks if the user wants to open a file based on ECTO_EDITOR.

  By default, it attempts to open the file and line using the
  `file:line` notation. For example, if your editor is called
  `subl`, it will open the file as:

      subl path/to/file:line

  It is important that you choose an editor command that does
  not block nor that attempts to run an editor directly in the
  terminal. Command-line based editors likely need extra
  configuration so they open up the given file and line in a
  separate window.

  Custom editors are supported by using the `__FILE__` and
  `__LINE__` notations, for example:

      ECTO_EDITOR="my_editor +__LINE__ __FILE__"

  and Elixir will properly interpolate values.

  """
  @spec open?(binary, non_neg_integer) :: boolean
  def open?(file, line \\ 1) do
    editor = System.get_env("ECTO_EDITOR") || ""

    if editor != "" do
      command =
        if editor =~ "__FILE__" or editor =~ "__LINE__" do
          editor
          |> String.replace("__FILE__", inspect(file))
          |> String.replace("__LINE__", Integer.to_string(line))
        else
          "#{editor} #{inspect(file)}:#{line}"
        end

      Mix.shell().cmd(command)
      true
    else
      false
    end
  end

  @doc """
  Gets a path relative to the application path.

  Raises on umbrella application.
  """
  def no_umbrella!(task) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "Cannot run task #{inspect(task)} from umbrella project root. " <>
          "Change directory to one of the umbrella applications and try again"
      )
    end
  end

  @doc """
  Returns `true` if module implements behaviour.
  """
  def ensure_implements(module, behaviour, message) do
    all = Keyword.take(module.__info__(:attributes), [:behaviour])

    unless [behaviour] in Keyword.values(all) do
      Mix.raise(
        "Expected #{inspect(module)} to implement #{inspect(behaviour)} " <>
          "in order to #{message}"
      )
    end
  end

  # endregion [ copied from https://github.com/elixir-ecto/ecto_sql@lib/mix/ecto_sql.ex  ]

  # region [ copied from https://github.com/elixir-ecto/ecto_sql@lib/mix/ecto_sql.ex ]

  def ensure_migrations_paths(repo, opts) do
    paths = Keyword.get_values(opts, :migrations_path)
    paths = if paths == [], do: [Path.join(source_repo_priv(repo), "migrations")], else: paths

    if not Mix.Project.umbrella?() do
      for path <- paths, not File.dir?(path) do
        raise_missing_migrations(Path.relative_to_cwd(path), repo)
      end
    end

    paths
  end

  defp raise_missing_migrations(path, repo) do
    Mix.raise("""
    Could not find migrations directory #{inspect(path)}
    for repo #{inspect(repo)}.

    This may be because you are in a new project and the
    migration directory has not been created yet. Creating an
    empty directory at the path above will fix this error.

    If you expected existing migrations to be found, please
    make sure your repository has been properly configured
    and the configured path exists.
    """)
  end

  @doc """
  Returns the private repository path relative to the source.
  """
  def source_repo_priv(repo) do
    config = repo.config()
    priv = config[:priv] || "priv/#{repo |> Module.split() |> List.last() |> Macro.underscore()}"
    app = Keyword.fetch!(config, :otp_app)
    Path.join(Mix.Project.deps_paths()[app] || File.cwd!(), priv)
  end

  # endregion [ copied from https://github.com/elixir-ecto/ecto_sql@lib/mix/ecto_sql.ex  ]
end
