Code.require_file("../../mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Mo.Gen.MigrationTest do
  @moduledoc false

  use ExUnit.Case
  import MixHelper
  import ExUnit.CaptureIO

  alias Mix.Tasks.Mo.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  describe "options" do
    test "it prints the version", config do
      in_tmp_project(config.test, fn ->
        assert capture_io(fn ->
                 Gen.Migration.run(~w(-v))
               end) =~ "Mo.Gen.Migration  v0.0.1"
      end)
    end
  end

  test "parse_migration_type/1", config do
    parse = &Gen.Migration.parse_migration_type/1

    assert(parse.("add_bob_to_products")) ==
      {:add_column, %{"column" => "bob", "table" => "products"}}

    assert(parse.("add_bob_index_to_products")) ==
      {:add_index, %{"index_name" => "bob", "table" => "products"}}

    assert(parse.("add_to_products")) ==
      {:add_columns, %{"table" => "products"}}

    assert(parse.("remove_bob_from_products")) ==
      {:remove_column, %{"column" => "bob", "table" => "products"}}

    assert(parse.("remove_from_products")) ==
      {:remove_columns, %{"table" => "products"}}

    assert(parse.("remove_bob_index_from_products")) ==
      {:remove_index, %{"index_name" => "bob", "table" => "products"}}

    assert(parse.("remove_index_from_products")) ==
      {:remove_index, %{"table" => "products"}}
  end
end
