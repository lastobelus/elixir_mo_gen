Code.require_file("../mix_helper.exs", __DIR__)

defmodule ElixirMoGen.MigrationTest do
  @moduledoc false

  use ExUnit.Case


  import MixHelper

  alias ElixirMoGen.Migration

  setup do
    Mix.Task.clear()
    Application.put_env(:mo_gen, :ignore_paths, nil)
    :ok
  end


    describe "migration_module/0" do
      test "migration_module reads the migration module name", config do
        in_tmp_ecto_project(config.test, fn ->
          assert Migration.migration_module == Ecto.Migration
        end)
      end
    end

    describe "column_options_template/1" do
    end

    describe "add_columns_template/1" do
      test "adds a single column" do
        assert Migration.add_columns_template(
            columns: %{size: %{type: :string}},
            table: "widgets"
        ) =~ """
             alter table(widgets) do
               add :size, :string
             end
             """

      end
      test "adds a multiple columns" do
        assert Migration.add_columns_template(
            columns: %{name: %{type: :string}, size: %{type: :float}},
            table: "widgets"
        ) =~ """
             alter table(widgets) do
               add :name, :string
               add :size, :float
             end
             """

      end
    end

end
