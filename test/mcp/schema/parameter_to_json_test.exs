defmodule ArkeAi.Mcp.Schema.ParameterToJsonTest do
  use ExUnit.Case, async: true

  alias ArkeAi.Mcp.Schema.ParameterToJson
  alias Arke.Core.Unit

  defp param(arke_id, data \\ %{}),
    do: %Unit{arke_id: arke_id, data: data}

  describe "string" do
    test "base type" do
      assert %{"type" => "string"} = ParameterToJson.convert(param(:string))
    end

    test "with min and max length" do
      result = ParameterToJson.convert(param(:string, %{min_length: 2, max_length: 100}))
      assert result["minLength"] == 2
      assert result["maxLength"] == 100
    end

    test "with enum values" do
      values = [%{label: "a", value: "a"}, %{label: "b", value: "b"}, %{label: "c", value: "c"}]
      result = ParameterToJson.convert(param(:string, %{values: values}))
      assert result["enum"] == ["a", "b", "c"]
    end

    test "nil constraints are omitted" do
      result = ParameterToJson.convert(param(:string, %{min_length: nil, max_length: nil}))
      refute Map.has_key?(result, "minLength")
      refute Map.has_key?(result, "maxLength")
    end
  end

  describe "integer" do
    test "base type" do
      assert %{"type" => "integer"} = ParameterToJson.convert(param(:integer))
    end

    test "with min and max" do
      result = ParameterToJson.convert(param(:integer, %{min: 0, max: 100}))
      assert result["minimum"] == 0
      assert result["maximum"] == 100
    end

    test "with enum values" do
      values = [%{label: "one", value: 1}, %{label: "two", value: 2}, %{label: "three", value: 3}]
      result = ParameterToJson.convert(param(:integer, %{values: values}))
      assert result["enum"] == [1, 2, 3]
    end

    test "nil constraints are omitted" do
      result = ParameterToJson.convert(param(:integer, %{min: nil, max: nil}))
      refute Map.has_key?(result, "minimum")
      refute Map.has_key?(result, "maximum")
    end
  end

  describe "float" do
    test "base type" do
      assert %{"type" => "number"} = ParameterToJson.convert(param(:float))
    end

    test "with min and max" do
      result = ParameterToJson.convert(param(:float, %{min: 0.5, max: 9.9}))
      assert result["minimum"] == 0.5
      assert result["maximum"] == 9.9
    end

    test "nil constraints are omitted" do
      result = ParameterToJson.convert(param(:float, %{min: nil, max: nil}))
      refute Map.has_key?(result, "minimum")
      refute Map.has_key?(result, "maximum")
    end
  end

  describe "boolean" do
    test "base type" do
      assert %{"type" => "boolean"} = ParameterToJson.convert(param(:boolean))
    end
  end

  describe "date / time types" do
    test "date has string type and date format" do
      result = ParameterToJson.convert(param(:date))
      assert result["type"] == "string"
      assert result["format"] == "date"
    end

    test "datetime has string type and date-time format" do
      result = ParameterToJson.convert(param(:datetime))
      assert result["type"] == "string"
      assert result["format"] == "date-time"
    end

    test "time has string type and time format" do
      result = ParameterToJson.convert(param(:time))
      assert result["type"] == "string"
      assert result["format"] == "time"
    end
  end

  describe "dict" do
    test "base type" do
      assert %{"type" => "object"} = ParameterToJson.convert(param(:dict))
    end
  end

  describe "list" do
    test "base type" do
      assert %{"type" => "array"} = ParameterToJson.convert(param(:list))
    end
  end

  describe "multiple" do
    test "string with enum becomes an array of enum items" do
      values = [%{label: "Weather", value: "weather"}, %{label: "Sum", value: "sum"}]

      assert ParameterToJson.convert(param(:string, %{multiple: true, values: values})) ==
               %{
                 "type" => "array",
                 "items" => %{"type" => "string", "enum" => ["weather", "sum"]}
               }
    end

    test "default moves from the item to the array" do
      result =
        ParameterToJson.convert(param(:integer, %{multiple: true, default_integer: [1, 2]}))

      assert result == %{
               "type" => "array",
               "items" => %{"type" => "integer"},
               "default" => [1, 2]
             }
    end

    test "link is a string, or an array of strings when multiple" do
      assert ParameterToJson.convert(param(:link)) == %{"type" => "string"}

      assert ParameterToJson.convert(param(:link, %{multiple: true})) ==
               %{"type" => "array", "items" => %{"type" => "string"}}
    end

    test "multiple: false keeps the scalar schema" do
      assert ParameterToJson.convert(param(:string, %{multiple: false})) == %{"type" => "string"}
    end
  end
end
