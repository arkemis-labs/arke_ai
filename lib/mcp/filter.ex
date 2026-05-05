defmodule ArkeAi.Mcp.Filter do
  @moduledoc "Recursive filter conversion: JSON filter tree → Arke query."

  alias Arke.QueryManager
  alias Arke.Core.Query.{Filter, BaseFilter}
  alias Arke.Boundary.ParameterManager

  @ops ~w(eq contains icontains startswith istartswith endswith iendswith lte lt gt gte in isnull)
  @logics ~w(and or)

  def to_query(query, nil, _project), do: query

  def to_query(query, filter_node, project) do
    case convert(filter_node, project) do
      %Filter{logic: :and, negate: negate, base_filters: filters} ->
        QueryManager.and_(query, negate, filters)

      %Filter{logic: :or, negate: negate, base_filters: filters} ->
        QueryManager.or_(query, negate, filters)

      %BaseFilter{} = leaf ->
        QueryManager.and_(query, false, [leaf])
    end
  end

  def schema_defs do
    %{
      "filterNode" => %{
        "oneOf" => [
          %{"$ref" => "#/$defs/filterLeaf"},
          %{"$ref" => "#/$defs/filterGroup"}
        ]
      },
      "filterLeaf" => %{
        "type" => "object",
        "properties" => %{
          "field"  => %{"type" => "string"},
          "op"     => %{"type" => "string", "enum" => @ops},
          "value"  => %{},
          "negate" => %{"type" => "boolean"}
        },
        "required" => ["field", "op", "value"]
      },
      "filterGroup" => %{
        "type" => "object",
        "properties" => %{
          "logic"   => %{"type" => "string", "enum" => @logics},
          "negate"  => %{"type" => "boolean"},
          "filters" => %{
            "type"  => "array",
            "items" => %{"$ref" => "#/$defs/filterNode"}
          }
        },
        "required" => ["logic", "filters"]
      }
    }
  end

  defp convert(%{"logic" => logic, "filters" => children} = node, project)
       when logic in @logics do
    %Filter{
      logic: String.to_existing_atom(logic),
      negate: Map.get(node, "negate", false),
      base_filters: Enum.map(children, &convert(&1, project))
    }
  end

  defp convert(%{"field" => field, "op" => op, "value" => value} = node, project)
       when op in @ops do
    parameter = ParameterManager.get(field, project)

    QueryManager.condition(
      parameter,
      String.to_existing_atom(op),
      value,
      Map.get(node, "negate", false)
    )
  end
end
