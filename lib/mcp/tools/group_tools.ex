defmodule ArkeAi.Mcp.Tools.GroupTools do
  @moduledoc "Builds and executes tools for `:group`."

  alias Arke.Boundary.{ArkeManager, GroupManager}
  alias Arke.LinkManager
  alias Arke.QueryManager
  alias ArkeAi.Mcp.Filter
  alias ArkeAi.Mcp.Permission
  alias ArkeAi.Mcp.Schema.ParameterToJson

  @system_params [:id, :arke_id, :metadata, :inserted_at, :updated_at]

  def build(id, ops, project) do
    case GroupManager.get(id, project) do
      nil   -> []
      group -> Enum.map(ops, &build_tool(group, &1))
    end
  end

  def resolve(id, ops, name) do
    Enum.find(ops, fn op -> tool_name(id, op) == name end)
  end

  defp tool_name(id, :add_arke),    do: "add_arke_to_#{id}"
  defp tool_name(id, :remove_arke), do: "remove_arke_from_#{id}"
  defp tool_name(id, op),           do: "#{op}_#{id}"

  def execute(id, :list, args, %{project: project, member: member, permission: perm}) do
    units =
      [project: project, arke: nil]
      |> QueryManager.query()
      |> QueryManager.filter(:group_id, :eq, id, false)
      |> Permission.apply_to_query(perm, member)
      |> QueryManager.offset(Map.get(args, "offset", 0))
      |> QueryManager.limit(Map.get(args, "limit", 10))
      |> QueryManager.all()

    {:ok, units}
  end

  def execute(id, :get, %{"id" => unit_id}, %{project: project, member: member, permission: perm}) do
    unit =
      [project: project, arke: nil]
      |> QueryManager.query()
      |> QueryManager.filter(:group_id, :eq, id, false)
      |> Permission.apply_to_query(perm, member)
      |> QueryManager.filter(:id, :eq, unit_id, false)
      |> QueryManager.one()

    case unit do
      nil  -> {:error, "not found"}
      unit -> {:ok, unit}
    end
  end

  def execute(id, :search, args, %{project: project, member: member, permission: perm}) do
    query =
      [project: project, arke: nil]
      |> QueryManager.query()
      |> QueryManager.filter(:group_id, :eq, id, false)
      |> Permission.apply_to_query(perm, member)
      |> Filter.to_query(Map.get(args, "filter"), project)
      |> apply_order(Map.get(args, "order", []))
      |> QueryManager.offset(Map.get(args, "offset", 0))
      |> QueryManager.limit(Map.get(args, "limit", 10))

    {:ok, QueryManager.all(query)}
  end

  def execute(id, :list_arkes, _args, %{project: project}) do
    case GroupManager.get(id, project) do
      nil   -> {:error, "group not found"}
      group -> {:ok, GroupManager.get_arke_list(group)}
    end
  end

  def execute(id, :get_schema, _args, %{project: project}) do
    case GroupManager.get(id, project) do
      nil ->
        {:error, "group not found"}

      group ->
        params = GroupManager.get_parameters(group)
        {:ok, %{"properties" => build_properties(params)}}
    end
  end

  def execute(id, :add_arke, %{"arke_id" => arke_id}, %{project: project}) do
    with %_{} = group <- GroupManager.get(id, project) || {:error, "group not found"},
         %_{} = arke <- ArkeManager.get(arke_id, project) || {:error, "arke not found"} do
      LinkManager.add_node(project, group, arke, "group")
    end
  end

  def execute(id, :remove_arke, %{"arke_id" => arke_id}, %{project: project}) do
    with %_{} = group <- GroupManager.get(id, project) || {:error, "group not found"},
         %_{} = arke <- ArkeManager.get(arke_id, project) || {:error, "arke not found"} do
      LinkManager.delete_node(project, group, arke, "group")
    end
  end

  defp apply_order(query, order) do
    Enum.reduce(order, query, fn %{"field" => field, "direction" => dir}, q ->
      QueryManager.order(q, String.to_existing_atom(field), String.to_existing_atom(dir))
    end)
  end

  defp build_tool(group, :list) do
    %{
      "name" => tool_name(group.id, :list),
      "description" => "List all units across member arkes of #{label(group)}",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "offset" => %{"type" => "integer", "default" => 0},
          "limit"  => %{"type" => "integer", "default" => 10}
        }
      }
    }
  end

  defp build_tool(group, :get) do
    %{
      "name" => tool_name(group.id, :get),
      "description" => "Get a unit by id within the #{label(group)} group",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{"id" => %{"type" => "string"}},
        "required" => ["id"]
      }
    }
  end

  defp build_tool(group, :search) do
    %{
      "name" => tool_name(group.id, :search),
      "description" => "Search units across member arkes of #{label(group)} with nested filters",
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
        "$defs" => Filter.schema_defs()
      }
    }
  end

  defp build_tool(group, :list_arkes) do
    %{
      "name" => tool_name(group.id, :list_arkes),
      "description" => "List the member arkes of the #{label(group)} group",
      "inputSchema" => %{"type" => "object", "properties" => %{}}
    }
  end

  defp build_tool(group, :get_schema) do
    %{
      "name" => tool_name(group.id, :get_schema),
      "description" => "Get the union parameter schema across member arkes of #{label(group)}",
      "inputSchema" => %{"type" => "object", "properties" => %{}}
    }
  end

  defp build_tool(group, :add_arke) do
    %{
      "name" => tool_name(group.id, :add_arke),
      "description" => "Add an arke to the #{label(group)} group",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{"arke_id" => %{"type" => "string"}},
        "required" => ["arke_id"]
      }
    }
  end

  defp build_tool(group, :remove_arke) do
    %{
      "name" => tool_name(group.id, :remove_arke),
      "description" => "Remove an arke from the #{label(group)} group",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{"arke_id" => %{"type" => "string"}},
        "required" => ["arke_id"]
      }
    }
  end

  defp label(group), do: group.data[:label] || group.id

  defp build_properties(params) do
    params
    |> Enum.reject(&(&1.id in @system_params))
    |> Enum.reduce(%{}, fn param, acc ->
      Map.put(acc, to_string(param.id), ParameterToJson.convert(param))
    end)
  end
end
