#  Copied from  https://github.com/phoenixframework/phoenix.git

# Get Mix output sent to the current
# process to avoid polluting tests.
Mix.shell(Mix.Shell.Process)

# Mock live reloading for testing the generated application.
defmodule Phoenix.LiveReloader do
  def init(opts), do: opts
  def call(conn, _), do: conn
end

defmodule MixHelper do
  import ExUnit.Assertions
  import ExUnit.CaptureIO

  @app_name :elixir_mo_gen
  @test_app_name :elixir_mo_gen_test

  # default deps versions
  @deps %{
    phoenix: "~> 1.7",
    ecto_sql: "~> 3.10",
    postgrex: ">= 0.0.0"
  }

  def tmp_path do
    Path.expand("../tmp", __DIR__)
  end

  defp random_string(len) do
    len |> :crypto.strong_rand_bytes() |> Base.encode64() |> binary_part(0, len)
  end

  def in_tmp(which, function) do
    path = Path.join([tmp_path(), random_string(10), to_string(which)])

    try do
      File.rm_rf!(path)
      File.mkdir_p!(path)
      File.cd!(path, function)
    rescue
      e ->
        reraise e, __STACKTRACE__
    after
      File.rm_rf!(path)
    end
  end

  def in_tmp_phx_project(test, func, deps \\ [:phoenix]) do
    app = @test_app_name

    in_tmp_project(test, deps, fn ->
      File.mkdir_p!("lib/#{app}_web")
      File.write!("lib/#{app}_web/#{app}_web.ex", web_module_contents(app))

      func.()
    end)
  end

  def in_tmp_ecto_project(test, func) do
    app = @test_app_name

    in_tmp_project(test, [:ecto_sql, :postgrex], fn ->
      File.mkdir_p!("lib/#{app}")
      File.write!("lib/#{app}/repo.ex", repo_module_contents(app))
      File.mkdir_p!("config")
      File.write!("config/config.exs", config_for_ecto_contents(app))
      func.()
    end)
  end

  def in_tmp_live_umbrella_project(test, func) do
    in_tmp_umbrella_project(test, fn ->
      File.mkdir_p!("#{@test_app_name}/lib")
      File.mkdir_p!("#{@test_app_name}_web/lib")
      File.touch!("#{@test_app_name}/lib/#{@test_app_name}.ex")
      File.touch!("#{@test_app_name}_web/lib/#{@test_app_name}_web.ex")
      func.()
    end)
  end

  def in_tmp_project(which, function) do
    in_tmp_project(which, [], function)
  end

  def in_tmp_project(which, deps, function) do
    conf_before = Application.get_env(@app_name, :generators) || []
    path = Path.join([tmp_path(), random_string(10), to_string(which)])

    try do
      File.rm_rf!(path)
      File.mkdir_p!(path)

      File.cd!(path, fn ->
        File.mkdir_p!("lib")
        File.mkdir_p!("_build")
        File.mkdir_p!("test")
        File.write!("mix.exs", mixfile_contents(@test_app_name, deps))
        File.write!("test/test_helper.exs", "ExUnit.start()\n")

        in_project(@test_app_name, path, fn _module ->
          function.()
        end)
      end)
    rescue
      e ->
        IO.puts(Exception.format(:error, e, __STACKTRACE__))
        reraise e, __STACKTRACE__
    after
      File.rm_rf!(path)
      Application.put_env(@app_name, :generators, conf_before)
    end
  end

  def in_tmp_umbrella_project(which, function) do
    conf_before = Application.get_env(@app_name, :generators) || []
    path = Path.join([tmp_path(), random_string(10), to_string(which)])

    try do
      apps_path = Path.join(path, "apps")
      config_path = Path.join(path, "config")
      File.rm_rf!(path)
      File.mkdir_p!(path)
      File.mkdir_p!(apps_path)
      File.mkdir_p!(config_path)
      File.touch!(Path.join(path, "mix.exs"))

      for file <- ~w(config.exs dev.exs test.exs prod.exs prod.secret.exs) do
        File.write!(Path.join(config_path, file), "use Mix.Config\n")
      end

      File.cd!(apps_path, function)
    after
      Application.put_env(@app_name, :generators, conf_before)
      File.rm_rf!(path)
    end
  end

  def in_project(app, path, fun) do
    %{name: name, file: file} = Mix.Project.pop()

    try do
      capture_io(:stderr, fn ->
        Mix.Project.in_project(app, path, [], fun)
      end)
    after
      Mix.Project.push(name, file)
    end
  end

  def assert_file(file) do
    assert File.regular?(file), "Expected #{file} to exist, but does not"
  end

  def refute_file(file) do
    refute File.regular?(file), "Expected #{file} to not exist, but it does"
  end

  def assert_file(file, match) do
    cond do
      is_list(match) ->
        assert_file(file, &Enum.each(match, fn m -> assert &1 =~ m end))

      is_binary(match) or Kernel.is_struct(match) ->
        assert_file(file, &assert(&1 =~ match))

      is_function(match, 1) ->
        assert_file(file)
        match.(File.read!(file))

      true ->
        raise inspect({file, match})
    end
  end

  def assert_timestamped_file(file, match) do
    cond do
      is_list(match) ->
        assert_timestamped_file(file, &Enum.each(match, fn m -> assert &1 =~ m end))

      is_binary(match) or Kernel.is_struct(match) ->
        assert_timestamped_file(file, &assert(&1 =~ match))

      is_function(match, 2) ->
        {basename, dir, file} = find_timestamped_file(file)
        assert(file, "Expected #{dir}/DDDDDDDDDDDDDD_#{basename} to exist, but does not")
        path = Path.join(dir, file)
        match.(path, File.read!(path))

      true ->
        raise inspect({file, match})
    end
  end

  def assert_timestamped_file(file) do
    {basename, dir, file} = find_timestamped_file(file)
    assert(file, "Expected #{dir}/DDDDDDDDDDDDDD_#{basename} to exist, but does not")
  end

  def find_timestamped_file(path) do
    dir = path |> Path.expand() |> Path.dirname()
    basename = path |> Path.basename()
    assert File.dir?(dir), "Expected #{dir} to be a directory, but is not"

    file =
      File.ls!(dir)
      |> Enum.find(fn f ->
        String.match?(f, ~r/^[\d]{14}_#{basename}/) && File.regular?(Path.join(dir, f))
      end)

    {basename, dir, file}
  end

  def assert_file_compiles(file) do
    assert File.regular?(file), "Expected #{file} to exist, but does not"
    msgid = Ecto.UUID.generate()

    output =
      capture_io(:stderr, fn ->
        try do
          Code.eval_file(file)
        rescue
          e -> send(self(), {msgid, e})
        end
      end)

    receive do
      {^msgid, err} ->
        flunk("""
        Expected #{err.file}
        ```
        #{File.read!(file)}```
        to compile, but #{err.description}

        #{output}
        """)
    after
      0 -> file
    end
  end

  def assert_code_compiles(code, path \\ "") do
    msgid = Ecto.UUID.generate()

    output =
      capture_io(:stderr, fn ->
        try do
          Code.eval_string(code)
        rescue
          e ->
            send(self(), {msgid, e})
        end
      end)

    receive do
      {^msgid, err} ->
        flunk("""
        Expected #{path}
        ```
        #{code}```
        to compile, but #{err.description}

        #{output}
        """)
    after
      0 -> nil
    end
  end

  def with_generator_env(new_env, fun) do
    Application.put_env(@app_name, :generators, new_env)

    try do
      fun.()
    after
      Application.delete_env(@app_name, :generators)
    end
  end

  def mixfile_contents(app, deps \\ []) do
    s = """
    defmodule #{Macro.camelize(to_string(app))}.Mixfile do
      use Mix.Project

      def project do
        [
          app: #{inspect(app)},
          version: "0.1.0",
          deps: deps(),
          prune_code_paths: false
        ]
      end

      def application do
        [extra_applications: [:logger]]
      end

      defp deps do
        #{inspect(Enum.map(deps, &get_dep/1))}
      end
    end
    """

    # IO.puts(s)
    s
  end

  def web_module_contents(app) do
    """
    defmodule #{Macro.camelize(to_string(app))}Web do
      def controller do
      end

      def view do
      end

      def live_view do
      end

      def live_component do
      end

      def router do
      end

      def channel do
      end

      defp view_helpers do
      end
    end
    """
  end

  def repo_module_contents(app) do
    """
    defmodule #{Macro.camelize(to_string(app))}.Repo do
      use Ecto.Repo,
      otp_app: :#{app},
      adapter: Ecto.Adapters.Postgres
    end
    """
  end

  def config_for_ecto_contents(app) do
    app_module = Macro.camelize(to_string(app))

    """
    import Config

    config :#{app}, ecto_repos: [#{app_module}.Repo]
    config :#{app}, #{app_module}.Repo,
      database: "#{@app_name}",
      username: "user",
      password: "pass",
      hostname: "localhost"
    """
  end

  def get_dep(dep) when is_tuple(dep), do: dep

  def get_dep(dep) when is_atom(dep) do
    dep_spec = List.keyfind(Mix.Project.config()[:deps], dep, 0, @deps[dep])
    # {dep, dep_spec}
    dep_spec
    # |> dbg()
  end

  def umbrella_mixfile_contents do
    """
    defmodule Umbrella.MixProject do
      use Mix.Project

      def project do
        [
          apps_path: "apps",
          deps: deps()
        ]
      end

      defp deps do
        []
      end
    end
    """
  end

  # def flush do
  #   receive do
  #     _ -> flush()
  #   after
  #     0 -> :ok
  #   end
  # end

  def compile(test, opts \\ []) do
    log("compiling in tmp_project for `#{test}`...", opts)

    with :ok <- Mix.Task.run("deps.get"),
         {:ok, []} <- Mix.Task.run("compile", ["--return-errors"]) do
      log("successfully compiled", opts)
      :ok
    else
      {_, diagnostics} ->
        log("error", verbose: true)
        print_diagnostics(diagnostics)
    end
  end

  defp print_diagnostics(diagnostics) do
    Enum.map(diagnostics, fn d ->
      log("error\n#{d.message}", verbose: true)
    end)
  end

  def log(msg, opts) do
    if opts[:verbose] do
      IO.puts(IO.ANSI.color_background(16) <> IO.ANSI.color(130) <> msg <> IO.ANSI.reset())
    end
  end

  def inspect_file(path) do
    IO.puts("------------------- #{path} --------------------------")
    IO.puts(File.read!(path))
    IO.puts("----------------------------------------------")
  end

  def inspect_app_dir(opts \\ []) do
    IO.puts("----------------------------------------------")
    IO.puts("File.cwd!(): #{inspect(File.cwd!())}")
    IO.puts("File.ls!(): #{inspect(File.ls!())}")

    {dir, opts} = Keyword.pop(opts, :dir)
    tree_opts = (dir && [dir]) || []

    tree_opts =
      Enum.reduce(opts, tree_opts, fn
        {:only, value}, acc -> acc ++ ["-P"] ++ value
        {:except, value}, acc -> acc ++ ["-I"] ++ value
        {:dirs, true}, acc -> acc ++ ["-d"]
        {:prune, true}, acc -> acc ++ ["--prune"]
        {:depth, depth}, acc -> acc ++ ["-L", depth]
      end)

    IO.puts("tree_opts: #{inspect(tree_opts)}")
    {tree, _x} = System.cmd("tree", tree_opts)
    IO.puts(tree)

    # hi
    IO.puts("----------------------------------------------")
  end
end
