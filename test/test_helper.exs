ExUnit.start()

File.cd!("priv/test_app", fn ->
  IO.puts("compiling test_app")
  {output, result} = System.cmd("mix", [], stderr_to_stdout: true, env: [{"MIX_ENV", "test"}])

  if result != 0 do
    Mix.raise("test_app compile failed:\n#{output}")
  end
end)
