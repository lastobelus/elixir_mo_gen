defmodule ElixirMoGen.Migration.ColumnTest do
  @moduledoc false
  use ExUnit.Case

  alias ElixirMoGen.Migration.Column

  describe "parse_single_column/3" do
    test "uses the passed name when name is ommitted in the arg" do
      assert Column.parse_single_column(
               ":float",
               "size"
             ) ==
               {:ok,
                %{
                  size: %{type: :float}
                }}
    end

    test "is ok when arg also specifies column name" do
      assert Column.parse_single_column(
               "size:float",
               "size"
             ) ==
               {:ok,
                %{
                  size: %{type: :float}
                }}
    end

    test "errors when column name is blank and only a type is specified" do
      assert Column.parse_single_column(
               ":float",
               ""
             ) ==
               {:error, "column name is missing"}
    end

    test "errors when type is unknown" do
      assert Column.parse_single_column(
               ":bogus",
               "size"
             ) ==
               {:error, "invalid option/type `bogus` for column `size`"}
    end

    test "handles type aliases" do
      assert Column.parse_single_column(
               "size:f",
               "size"
             ) ==
               {:ok,
                %{
                  size: %{type: :float}
                }}
    end
  end

  describe "single_column_from_migration" do
    test "returns type :string" do
      assert Column.single_column_from_migration(
        %{column: "size", table: "widgets"}
      ) ==
        %{size: %{type: :string}}
    end
  end

end
