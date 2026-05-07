defmodule ArkeAi.Mcp.Tools.Arke do
  @moduledoc "Builds and executes tools for `:arke`."

  alias Arke.Boundary.ArkeManager
  alias Arke.QueryManager
  alias ArkeAi.Mcp.Permission
  alias ArkeAi.Mcp.Schema.{ParameterToJson, SearchFilter}

  @system_params [:id, :arke_id, :metadata, :inserted_at, :updated_at]

  def build(id, ops, project) do
    case ArkeManager.get(id, project) do
      nil  -> []
      arke -> Enum.map(ops, &build_tool(arke, &1))
    end
  end

  def resolve(id, ops, name) do
    Enum.find(ops, fn op -> tool_name(id, op) == name end)
  end

  defp tool_name(id, op), do: "#{op}_#{id}"

  def execute(id, :list, args, %{project: project, member: member, permission: perm}) do
    units =
      [project: project, arke: id]
      |> QueryManager.query()
      |> Permission.apply_to_query(perm, member)
      |> QueryManager.offset(Map.get(args, "offset", 0))
      |> QueryManager.limit(Map.get(args, "limit", 10))
      |> QueryManager.all()

    {:ok, units}
  end

  def execute(id, :get, %{"id" => unit_id}, ctx) do
    case fetch_scoped(id, unit_id, ctx) do
      nil  -> {:error, "not found"}
      unit -> {:ok, unit}
    end
  end

  def execute(id, :search, args, %{project: project, member: member, permission: perm}) do
    query =
      [project: project, arke: id]
      |> QueryManager.query()
      |> Permission.apply_to_query(perm, member)
      |> SearchFilter.to_query(Map.get(args, "filter"), project)
      |> apply_order(Map.get(args, "order", []))
      |> QueryManager.offset(Map.get(args, "offset", 0))
      |> QueryManager.limit(Map.get(args, "limit", 10))

    {:ok, QueryManager.all(query)}
  end

  def execute(id, :create, args, %{project: project}) do
    arke = ArkeManager.get(id, project)
    QueryManager.create(project, arke, atomize_keys(args))
  end

  def execute(id, :update, %{"id" => unit_id} = args, ctx) do
    {_, args} = Map.pop(args, "id")

    case fetch_scoped(id, unit_id, ctx) do
      nil  -> {:error, "not found"}
      unit -> QueryManager.update(unit, atomize_keys(args))
    end
  end

  def execute(id, :delete, %{"id" => unit_id}, %{project: project} = ctx) do
    case fetch_scoped(id, unit_id, ctx) do
      nil ->
        {:error, "not found"}

      unit ->
        QueryManager.delete(project, unit)
        {:ok, %{deleted: unit_id}}
    end
  end

  defp fetch_scoped(arke_id, unit_id, %{project: project, member: member, permission: perm}) do
    [project: project, arke: arke_id]
    |> QueryManager.query()
    |> Permission.apply_to_query(perm, member)
    |> QueryManager.filter(:id, :eq, unit_id, false)
    |> QueryManager.one()
  end

  defp apply_order(query, order) do
    Enum.reduce(order, query, fn %{"field" => field, "direction" => dir}, q ->
      QueryManager.order(q, String.to_atom(field), String.to_atom(dir))
    end)
  end

  defp build_tool(arke, :list) do
    %{
      "name" => tool_name(arke.id, :list),
      "description" => "List #{label(arke)} units",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "offset" => %{"type" => "integer", "default" => 0},
          "limit"  => %{"type" => "integer", "default" => 10}
        }
      }
    }
  end

  defp build_tool(arke, :get) do
    %{
      "name" => tool_name(arke.id, :get),
      "description" => "Get a #{label(arke)} unit by id",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{"id" => %{"type" => "string"}},
        "required" => ["id"]
      }
    }
  end

  defp build_tool(arke, :search) do
    %{
      "name" => tool_name(arke.id, :search),
      "description" => "Search #{label(arke)} units with nested filters",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "filter" => %{"$ref" => "#/$defs/filterNode"},
          "order" => %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "properties" => %{
                "field" => %{"type" => "string"},
                "direction" => %{"type" => "string", "enum" => ["asc", "desc"]}
              },
              "required" => ["field", "direction"]
            }
          },
          "offset" => %{"type" => "integer", "default" => 0},
          "limit"  => %{"type" => "integer", "default" => 10}
        },
        "$defs" => SearchFilter.schema_defs()
      }
    }
  end

  defp build_tool(arke, :create) do
    params = ArkeManager.get_parameters(arke)
    properties = build_properties(params)
    required = required_fields(params)

    schema = %{"type" => "object", "properties" => properties}
    schema = if required == [], do: schema, else: Map.put(schema, "required", required)

    %{
      "name" => tool_name(arke.id, :create),
      "description" => "Create a #{label(arke)} unit",
      "inputSchema" => schema
    }
  end

  defp build_tool(arke, :update) do
    params = ArkeManager.get_parameters(arke)
    properties = Map.merge(%{"id" => %{"type" => "string"}}, build_properties(params))

    %{
      "name" => tool_name(arke.id, :update),
      "description" => "Update a #{label(arke)} unit by id",
      "inputSchema" => %{
        "type" => "object",
        "properties" => properties,
        "required" => ["id"]
      }
    }
  end

  defp build_tool(arke, :delete) do
    %{
      "name" => tool_name(arke.id, :delete),
      "description" => "Delete a #{label(arke)} unit by id",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{"id" => %{"type" => "string"}},
        "required" => ["id"]
      }
    }
  end

  defp label(arke), do: arke.data[:label] || arke.id

  defp atomize_keys(args) do
    Map.new(args, fn
      {k, v} when is_binary(k) ->
        try do
          {String.to_existing_atom(k), v}
        rescue
          ArgumentError -> {k, v}
        end

      kv ->
        kv
    end)
  end

  defp build_properties(params) do
    params
    |> Enum.reject(&(&1.id in @system_params))
    |> Enum.reduce(%{}, fn param, acc ->
      Map.put(acc, to_string(param.id), ParameterToJson.convert(param))
    end)
  end

  defp required_fields(params) do
    params
    |> Enum.reject(&(&1.id in @system_params))
    |> Enum.filter(&(&1.data[:required] == true))
    |> Enum.map(&to_string(&1.id))
  end
end
