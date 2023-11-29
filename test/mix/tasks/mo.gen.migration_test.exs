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

  @mo_gen_env_vars [
    "MO_GEN_MIGRATION_PREFIX",
    "MO_GEN_MIGRATION_PATH",
    "MO_GEN_MIGRATION_QUIET",
    "MO_GEN_MIGRATION_INDEX"
  ]

  setup do
    previous_env = System.get_env()

    Enum.each(@mo_gen_env_vars, fn env ->
      System.delete_env(env)
    end)

    on_exit(fn ->
      Enum.each(@mo_gen_env_vars, fn env ->
        System.delete_env(env)
      end)

      Map.filter(previous_env, fn {k, _} -> String.starts_with?(k, "MO_GEN_") end)
      |> System.put_env()
    end)

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
    parse = &Gen.Migration.parse_migration_type/2

    assert(
      parse.("add_bob_to_products", []) ==
        {:add_columns, %{column: "bob", table: "products"}}
    )

    assert(
      parse.("add_bob_index_to_products", []) ==
        {:add_index, %{index_name: "bob", table: "products"}}
    )

    assert(
      parse.("add_index_to_products", []) ==
        {:add_index, %{index_name: "", table: "products"}}
    )

    assert(
      parse.("add_to_products", []) ==
        {:add_columns, %{table: "products", column: ""}}
    )

    assert(
      parse.("remove_bob_from_products", []) ==
        {:remove_column, %{column: "bob", table: "products"}}
    )

    assert(
      parse.("remove_from_products", []) ==
        {:remove_columns, %{table: "products"}}
    )

    assert(
      parse.("remove_bob_index_from_products", []) ==
        {:remove_index, %{index_name: "bob", table: "products"}}
    )

    assert(
      parse.("remove_index_from_products", []) ==
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
          assert file =~ "Repo.Migrations.AddSizeToWidgets"
          assert file =~ ~r/add :size, :string$/m
        end)
      end)
    end

    test "it handles column in the migration name with specified type", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(add_size_to_widgets :float -r #{inspect(Repo)} -q))

        assert_timestamped_file(migration_file("repo", "add_size_to_widgets"), fn path, file ->
          assert_file_compiles(path)
          assert file =~ ~r/add :size, :float$/m
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
        end)
      end)
    end

    test "it sets not null with --no-null", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(
          add_size_to_widgets :float -r #{inspect(Repo)} -q
          --no-null
        ))

        assert_timestamped_file(migration_file("repo", "add_size_to_widgets"), fn path, file ->
          assert_file_compiles(path)
          assert file =~ ~r(add :size, :float, null: false)
        end)
      end)
    end

    test "it sets default value with --default", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(
          add_size_to_widgets :float -r #{inspect(Repo)} -q
          --default 10.0
        ))

        assert_timestamped_file(migration_file("repo", "add_size_to_widgets"), fn path, file ->
          assert_file_compiles(path)
          assert file =~ ~r(add :size, :float, default: 10.0)
        end)
      end)
    end

    test "it sets multiple options correctly", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(
          add_size_to_widgets :float -r #{inspect(Repo)} -q
          --default 10.0
          --no-null
          --comment
        ) ++ ["Add size to widgets"])

        assert_timestamped_file(migration_file("repo", "add_size_to_widgets"), fn path, file ->
          assert_file_compiles(path)
          assert file =~ ~r(add :size, :float, default: 10.0, null: false\s+# Add size to widgets)
        end)
      end)
    end

    test "it adds an index for the column", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(add_size_to_widgets -r #{inspect(Repo)} -q))

        assert_timestamped_file(migration_file("repo", "add_size_to_widgets"), fn path, file ->
          assert_file_compiles(path)
          assert file =~ "create index(:widgets, [:size])"
        end)
      end)
    end

    test "it skips index with --no-index", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(add_size_to_widgets -r #{inspect(Repo)} --no-index -q))

        assert_timestamped_file(migration_file("repo", "add_size_to_widgets"), fn path, file ->
          assert_file_compiles(path)
          refute file =~ "create index"
        end)
      end)
    end

    test "it uses --prefix", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(add_name_to_widgets -r #{inspect(Repo)} --prefix foo -q))

        assert_timestamped_file(migration_file("repo", "add_name_to_widgets"), fn path, file ->
          assert_file_compiles(path)
          assert file =~ "alter table(:widgets, prefix: :foo) do"
          assert file =~ ~r(add :name, :string)
          assert file =~ "create index(:widgets, [:name], prefix: :foo)"
        end)
      end)
    end

    test "it uses --prefix from env MO_GEN_MIGRATION_PREFIX", config do
      System.put_env("MO_GEN_MIGRATION_PREFIX", "foo")

      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(add_name_to_widgets -r #{inspect(Repo)} -q))

        assert_timestamped_file(migration_file("repo", "add_name_to_widgets"), fn path, file ->
          assert_file_compiles(path)
          assert file =~ "alter table(:widgets, prefix: :foo) do"
          assert file =~ ~r(add :name, :string)
          assert file =~ "create index(:widgets, [:name], prefix: :foo)"
        end)
      end)
    end
  end

  describe "add_to_TABLE columns migration" do
    test "it handles first column in the migration name", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(add_size_to_widgets :float units:string -r #{inspect(Repo)} -q))
        migration = migration_file("repo", "add_size_to_widgets")

        assert_timestamped_file(migration, fn path, file ->
          assert_file_compiles(path)
          assert file =~ "add :size, :float"
          assert file =~ "add :units, :string"
          assert file =~ "create index(:widgets, [:size])"
          assert file =~ "create index(:widgets, [:units])"
        end)
      end)
    end

    test "it handles descriptive name and fully specced columns", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(
          ~w(add_measurement_to_widgets size:float units:string -r #{inspect(Repo)} -q)
        )

        migration = migration_file("repo", "add_measurement_to_widgets")

        assert_timestamped_file(migration, fn path, file ->
          assert_file_compiles(path)
          assert file =~ "add :size, :float"
          assert file =~ "add :units, :string"
          assert file =~ "create index(:widgets, [:size])"
          assert file =~ "create index(:widgets, [:units])"
        end)
      end)
    end

    test "it handles camelCase migration name", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(AddGirthMeasurementToWidgets :float -r #{inspect(Repo)} -q))

        migration = migration_file("repo", "add_girth_measurement_to_widgets")

        assert_timestamped_file(migration, fn path, file ->
          assert_file_compiles(path)
          assert file =~ "Repo.Migrations.AddGirthMeasurementToWidgets"
          assert file =~ "add :girth_measurement, :float"
          assert file =~ "create index(:widgets, [:girth_measurement])"
        end)
      end)
    end

    test "it handles camelCase column names", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(AddToWidgets GirthMeasurement:float -r #{inspect(Repo)} -q))

        migration = migration_file("repo", "add_girth_measurement_to_widgets")

        assert_timestamped_file(migration, fn path, file ->
          assert_file_compiles(path)
          assert file =~ "Repo.Migrations.AddGirthMeasurementToWidgets"
          assert file =~ "add :girth_measurement, :float"
          assert file =~ "create index(:widgets, [:girth_measurement])"
        end)
      end)
    end

    test "it handles empty name and adds column list to name", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(
          ~w(add_to_widgets size:float units:string accuracy:integer -r #{inspect(Repo)} -q)
        )

        migration = migration_file("repo", "add_size_units_and_accuracy_to_widgets")

        assert_timestamped_file(migration, fn path, file ->
          assert_file_compiles(path)
          assert file =~ "add :size, :float"
          assert file =~ "add :units, :string"
          assert file =~ "add :accuracy, :integer"
          assert file =~ "create index(:widgets, [:size])"
          assert file =~ "create index(:widgets, [:units])"
          assert file =~ "create index(:widgets, [:accuracy])"
        end)
      end)
    end

    test "it handles column options in the column names", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(
          add_special_columns_to_widgets
          size:decimal{10,2}
          serial:string{20}:uniq:index
          required:string:no-null
          store_id:references{store}
          --no-index
          -r #{inspect(Repo)} -q
        ))

        assert_timestamped_file(migration_file("repo", "add_special_columns_to_widgets"), fn path,
                                                                                             file ->
          assert_file_compiles(path)
          IO.puts(file)
          assert file =~ "add :serial, :string, size: 20, unique: true"
          assert file =~ "add :size, :decimal, precision: 10, scale: 2"
          assert file =~ "add :required, :string, null: false"
          assert file =~ "add :store_id, references(:store)"

          assert file =~ "create index(:widgets, [:serial])"

          refute file =~ "create index(:widgets, [:required])"
          refute file =~ "create index(:widgets, [:store_id])"
          refute file =~ "create index(:widgets, [:size])"
        end)
      end)
    end
  end

  describe "add_INDEX_index_to_TABLE migration" do
    test "it adds single column index parsing column from name", config do
      in_tmp_ecto_project(config.test, fn ->
        Gen.Migration.run(~w(
            add_name_index_to_persons
            -r #{inspect(Repo)} -q))

        migration = migration_file("repo", "add_name_index_to_persons")

        assert_timestamped_file(migration, fn path, file ->
          assert_file_compiles(path)
          assert file =~ "Repo.Migrations.AddNameIndexToPersons"
          assert file =~ "create index(:persons, [:name])"
        end)
      end)
    end
  end
end
