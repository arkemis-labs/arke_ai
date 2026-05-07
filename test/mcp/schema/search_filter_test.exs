defmodule ArkeAi.Mcp.Schema.SearchFilterTest do
  use ExUnit.Case, async: true

  alias ArkeAi.Mcp.Schema.SearchFilter, as: Filter

  describe "schema_defs/0" do
    test "exposes filterNode, filterLeaf, filterGroup" do
      defs = Filter.schema_defs()
      assert Map.has_key?(defs, "filterNode")
      assert Map.has_key?(defs, "filterLeaf")
      assert Map.has_key?(defs, "filterGroup")
    end

    test "filterNode is a oneOf of leaf and group" do
      %{"oneOf" => one_of} = Filter.schema_defs()["filterNode"]
      refs = Enum.map(one_of, & &1["$ref"])
      assert "#/$defs/filterLeaf" in refs
      assert "#/$defs/filterGroup" in refs
    end

    test "filterLeaf requires field, op, value" do
      leaf = Filter.schema_defs()["filterLeaf"]
      assert leaf["type"] == "object"
      assert Enum.sort(leaf["required"]) == ["field", "op", "value"]
      assert "eq" in leaf["properties"]["op"]["enum"]
      assert "isnull" in leaf["properties"]["op"]["enum"]
    end

    test "filterGroup requires logic and filters, items reference filterNode recursively" do
      group = Filter.schema_defs()["filterGroup"]
      assert group["type"] == "object"
      assert Enum.sort(group["required"]) == ["filters", "logic"]
      assert group["properties"]["logic"]["enum"] == ["and", "or"]
      assert group["properties"]["filters"]["items"] == %{"$ref" => "#/$defs/filterNode"}
    end
  end

  describe "to_query/3" do
    test "returns the query unchanged when filter is nil" do
      assert Filter.to_query(:some_query, nil, :any_project) == :some_query
    end
  end
end
