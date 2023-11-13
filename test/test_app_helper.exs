defmodule TestAppHelper do
  @test_app_path "priv/test_app"


  def in_test_app(tmp_dir, func) do
    # dbg(tmp_dir)

    test_app_path = Path.expand(@test_app_path)

    File.cd!(tmp_dir, fn ->
      File.cp_r!(
        test_app_path,
        "test_app"
      )

      File.cd!("test_app", fn ->
        ignoring_module_conflicts( fn ->
          Mix.Project.in_project(:test_app, ".", fn _module ->
            func.()
          end)
        end)
      end)
    end)

  end

  def ignoring_module_conflicts(func) do
    # prevent warnings about redefining modules from clogging test output
    orig_ignore_module_conflict = Code.get_compiler_option(:ignore_module_conflict)
    Code.put_compiler_option(:ignore_module_conflict, true)

    func.()

    Code.put_compiler_option(:ignore_module_conflict, orig_ignore_module_conflict)
  end

  def run_mix_test(test, opts \\ []) do
    System.cmd("mix", ~w(clean))

    {output, _exit_status} = System.cmd("mix", ~w(test), stderr_to_stdout: true)

    [deps_build_output | test_output] = String.split(output, "==> #{@test_app_name}\nCompiling")

    cond do
      length(test_output) < 1 ->
        {:error, deps_build_output}

      true ->
        {:ok, Enum.join(test_output)}
    end
  end

end
