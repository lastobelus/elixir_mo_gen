defmodule ElixirMoGen.Migration.ColumnTest do
  @moduledoc false

  use ExUnit.Case

  alias ElixirMoGen.Migration.Column

  describe "parse_single_column/3" do
    test "uses the passed name when name is ommitted in the arg" do
      assert Column.parse_single_column(
               ":float",
               "size",
               %{"column" => "size", "table" => "products"}
             ) ==
               {:ok,
                %{
                  "size" => %{type: :float}
                }}
    end

    test "is ok when arg also specifies column name" do
      assert Column.parse_single_column(
               "size:float",
               "size",
               %{"column" => "size", "table" => "products"}
             ) ==
               {:ok,
                %{
                  "size" => %{type: :float}
                }}
    end

    test "errors if arg specifies different name then passed name" do
      assert Column.parse_single_column(
               "bob:float",
               "size",
               %{"column" => "size", "table" => "products"}
             ) ==
               {:error, "column `size` parsed from migration name does not match `bob`"}
    end

    test "errors when type is unknown" do
      assert Column.parse_single_column(
               ":bogus",
               "size",
               %{"column" => "size", "table" => "products"}
             ) ==
               {:error, "invalid type `bogus` for column `size`"}
    end
  end
end
