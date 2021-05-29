defmodule TestAppHelper do
  @test_app_path "priv/test_app"

  def in_test_app(test, func) do
    migration_path = Path.expand()

    try do
      File.cd!(path, function)
    after
      File.rm_rf!(migration_path)
    end
  end
end
