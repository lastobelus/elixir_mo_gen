Code.require_file("../../mix_helper.exs", __DIR__)
Code.require_file("../../test_app_helper.exs", __DIR__)

defmodule Mix.Tasks.Mo.Gen.MigrationTest do
  @moduledoc false

  use ExUnit.Case

  import MixHelper
  # import TestAppHelper

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mo.Gen

  @moduletag :tmp_dir

  setup do
    Mix.Task.clear()
    :ok
  end

  defmodule Repo do
    def __adapter__ do
      true
    end

    def config do
      [priv: "repo", otp_app: :elixir_mo_gen_test]
    end
  end

  defmodule Repo2 do
    def __adapter__ do
      true
    end

    def config do
      [priv: "repo2", otp_app: :elixir_mo_gen_test]
    end
  end

  def migration_file(repo, name), do: "#{repo}/migrations/#{name}.exs"

  describe "options" do
    test "it prints the version", config do
      in_tmp_project(config.test, fn ->
        assert capture_io(fn ->
                 Gen.Migration.run(~w(-v))
               end) =~ "Mo.Gen.Migration  v0.0.1"
      end)
    end
  end

  test "parse_migration_type/1" do
    parse = &Gen.Migration.parse_migration_type/1

    assert(
      parse.("add_bob_to_products") ==
        {:add_column, %{column: "bob", table: "products"}}
    )

    assert(
      parse.("add_bob_index_to_products") ==
        {:add_index, %{index_name: "bob", table: "products"}}
    )

    assert(
      parse.("add_index_to_products") ==
        {:add_index, %{index_name: "", table: "products"}}
    )

    assert(
      parse.("add_to_products") ==
        {:add_columns, %{table: "products"}}
    )

    assert(
      parse.("remove_bob_from_products") ==
        {:remove_column, %{column: "bob", table: "products"}}
    )

    assert(
      parse.("remove_from_products") ==
        {:remove_columns, %{table: "products"}}
    )

    assert(
      parse.("remove_bob_index_from_products") ==
        {:remove_index, %{index_name: "bob", table: "products"}}
    )

    assert(
      parse.("remove_index_from_products") ==
        {:remove_index, %{table: "products", index_name: ""}}
    )
  end

  describe "add_COLUMN_to_TABLE migration" do
    test "it handles column in the migration name with default type", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(add_size_to_widgets -r #{inspect(Repo)} -q))
        migration = migration_file("repo", "add_size_to_widgets")

        assert_timestamped_file(migration, fn path, file ->
          assert_file_compiles(path)
          assert file =~ "add :size, :string"
        end)
      end)
    end

    test "it handles column in the migration name with specified type", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(add_size_to_widgets :float -r #{inspect(Repo)} -q))

        assert_timestamped_file(migration_file("repo", "add_size_to_widgets"), fn path, file ->
          assert_file_compiles(path)
          assert file =~ "add :size, :float"
        end)
      end)
    end

    test "it sets a comment with --comment", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(
          add_size_to_widgets :float -r #{inspect(Repo)} -q
          --comment
        ) ++ ["Add size to widgets"])

        assert_timestamped_file(migration_file("repo", "add_size_to_widgets"), fn path, file ->
          assert_file_compiles(path)
          assert file =~ ~r(add :size, :float\s+# Add size to widgets)
          IO.puts(file)
        end)
      end)
    end
  end
end
