defmodule TestAppHelper do
  @test_app_path "priv/test_app"

  def in_test_app(tmp_dir, func) do
    test_app_path = Path.expand(@test_app_path)

    File.cd!(tmp_dir, fn ->
      # using system cp in archive mode shaves a few seconds off runs
      System.cmd("cp", ["-an", test_app_path, "test_app"])

      in_test_app_project(func)
    end)
  end

  defp in_test_app_project(func) do
    File.cd!("test_app", fn ->
      ignoring_module_conflicts(fn ->
        Mix.Project.in_project(:test_app, ".", fn _module ->
          func.()
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

  def run_mix_test do
    System.cmd("mix", ~w(clean))

    {output, _exit_status} = System.cmd("mix", ~w(test), stderr_to_stdout: true)

    if output =~ "Finished in" do
      {:ok, output}
    else
      {:error, output}
    end
  end
end
