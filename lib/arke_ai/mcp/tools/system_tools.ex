defmodule ArkeAi.Mcp.Tools.SystemTools do
  @moduledoc "Builds and executes tools for `:system` expose entries (arke / parameter / group definition CRUD + associations)."

  alias Arke.Boundary.{ArkeManager, GroupManager, ParameterManager}
  alias Arke.LinkManager
  alias Arke.QueryManager
  alias ArkeAi.Mcp.Notifications
  alias ArkeAi.Mcp.Schema.ParameterToJson

  @system_params [:id, :arke_id, :metadata, :inserted_at, :updated_at, :type]
  @parameter_types [:string, :integer, :float, :boolean, :date, :datetime, :time, :dict, :list, :link]

  def build(target, ops), do: Enum.map(materialize(target, ops), &build_op(target, &1))

  def resolve(target, ops, name) do
    Enum.find(materialize(target, ops), fn op -> tool_name(target, op) == name end)
  end

  defp materialize(:parameter, ops) do
    Enum.flat_map(ops, fn
      op when op in [:create, :update] -> Enum.map(@parameter_types, &{op, &1})
      op -> [op]
    end)
  end

  defp materialize(_, ops), do: ops

  defp tool_name(:parameter, {:create, type}), do: "create_#{type}_parameter"
  defp tool_name(:parameter, {:update, type}), do: "update_#{type}_parameter"
  defp tool_name(target, :list),               do: "list_#{target}s"
  defp tool_name(:arke, :add_parameter),       do: "add_parameter_to_arke"
  defp tool_name(:arke, :remove_parameter),    do: "remove_parameter_from_arke"
  defp tool_name(target, op),                  do: "#{op}_#{target}"

  # ---- list ----

  def execute(:arke, :list, args, %{project: project}) do
    {:ok, paginate(ArkeManager.get_all(project), args, &ArkeManager.get(&1, project))}
  end

  def execute(:parameter, :list, args, %{project: project}) do
    {:ok, paginate(ParameterManager.get_all(project), args, &ParameterManager.get(&1, project))}
  end

  def execute(:group, :list, args, %{project: project}) do
    {:ok, paginate(GroupManager.get_all(project), args, &GroupManager.get(&1, project))}
  end

  # ---- get ----

  def execute(:arke, :get, %{"id" => id}, %{project: project}) do
    case ArkeManager.get(id, project) do
      nil  -> {:error, "not found"}
      unit -> {:ok, unit}
    end
  end

  def execute(:parameter, :get, %{"id" => id}, %{project: project}) do
    case ParameterManager.get(id, project) do
      nil  -> {:error, "not found"}
      unit -> {:ok, unit}
    end
  end

  def execute(:group, :get, %{"id" => id}, %{project: project}) do
    case GroupManager.get(id, project) do
      nil  -> {:error, "not found"}
      unit -> {:ok, unit}
    end
  end

  # ---- create ----

  def execute(:arke, :create, args, %{project: project}) do
    arke = ArkeManager.get(:arke, :arke_system)

    QueryManager.create(project, arke, atomize_keys(args))
    |> notify_on_success(project)
  end

  def execute(:group, :create, args, %{project: project}) do
    arke = ArkeManager.get(:group, :arke_system)

    QueryManager.create(project, arke, atomize_keys(args))
    |> notify_on_success(project)
  end

  def execute(:parameter, {:create, type}, args, %{project: project}) do
    case ArkeManager.get(type, :arke_system) do
      nil ->
        {:error, "invalid parameter type: #{type}"}

      arke ->
        QueryManager.create(project, arke, atomize_keys(args))
        |> notify_on_success(project)
    end
  end

  # ---- update ----

  def execute(:arke, :update, %{"id" => id} = args, %{project: project}) do
    case ArkeManager.get(id, project) do
      nil ->
        {:error, "not found"}

      unit ->
        QueryManager.update(unit, atomize_keys(Map.delete(args, "id")))
        |> notify_on_success(project)
    end
  end

  def execute(:parameter, {:update, _type}, %{"id" => id} = args, %{project: project}) do
    case ParameterManager.get(id, project) do
      nil ->
        {:error, "not found"}

      unit ->
        QueryManager.update(unit, atomize_keys(Map.delete(args, "id")))
        |> notify_on_success(project)
    end
  end

  def execute(:group, :update, %{"id" => id} = args, %{project: project}) do
    case GroupManager.get(id, project) do
      nil ->
        {:error, "not found"}

      unit ->
        QueryManager.update(unit, atomize_keys(Map.delete(args, "id")))
        |> notify_on_success(project)
    end
  end

  # ---- delete ----

  def execute(:arke, :delete, %{"id" => id}, %{project: project}) do
    case ArkeManager.get(id, project) do
      nil ->
        {:error, "not found"}

      unit ->
        QueryManager.delete(project, unit)
        Notifications.tools_list_changed(project)
        {:ok, %{deleted: to_string(id)}}
    end
  end

  def execute(:parameter, :delete, %{"id" => id}, %{project: project}) do
    case ParameterManager.get(id, project) do
      nil ->
        {:error, "not found"}

      unit ->
        QueryManager.delete(project, unit)
        Notifications.tools_list_changed(project)
        {:ok, %{deleted: to_string(id)}}
    end
  end

  def execute(:group, :delete, %{"id" => id}, %{project: project}) do
    case GroupManager.get(id, project) do
      nil ->
        {:error, "not found"}

      unit ->
        QueryManager.delete(project, unit)
        Notifications.tools_list_changed(project)
        {:ok, %{deleted: to_string(id)}}
    end
  end

  # ---- arke / parameter associations ----

  def execute(:arke, :add_parameter, %{"arke_id" => arke_id, "parameter_id" => param_id} = args, %{project: project}) do
    metadata = Map.get(args, "metadata", %{})

    with %_{} = arke  <- ArkeManager.get(arke_id, project)       || {:error, "arke not found"},
         %_{} = param <- ParameterManager.get(param_id, project) || {:error, "parameter not found"} do
      LinkManager.add_node(project, arke, param, "parameter", metadata)
      |> notify_on_success(project)
    end
  end

  def execute(:arke, :remove_parameter, %{"arke_id" => arke_id, "parameter_id" => param_id}, %{project: project}) do
    with %_{} = arke  <- ArkeManager.get(arke_id, project)       || {:error, "arke not found"},
         %_{} = param <- ParameterManager.get(param_id, project) || {:error, "parameter not found"} do
      LinkManager.delete_node(project, arke, param, "parameter")
      |> notify_on_success(project)
    end
  end

  # ---- helpers ----

  defp notify_on_success({:ok, _} = result, project) do
    Notifications.tools_list_changed(project)
    result
  end

  defp notify_on_success(other, _project), do: other

  defp paginate(keys, args, fetch) do
    keys
    |> Enum.drop(Map.get(args, "offset", 0))
    |> Enum.take(Map.get(args, "limit", 10))
    |> Enum.map(fn {id, _} -> fetch.(id) end)
    |> Enum.reject(&is_nil/1)
  end

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

  # ---- tool definitions ----

  defp build_op(target, :list) do
    %{
      "name" => tool_name(target, :list),
      "description" => "List all #{target} definitions",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "offset" => %{"type" => "integer", "default" => 0},
          "limit"  => %{"type" => "integer", "default" => 10}
        }
      }
    }
  end

  defp build_op(target, :get) do
    %{
      "name" => tool_name(target, :get),
      "description" => "Get a #{target} definition by id",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{"id" => %{"type" => "string"}},
        "required" => ["id"]
      }
    }
  end

  defp build_op(target, :delete) do
    %{
      "name" => tool_name(target, :delete),
      "description" => "Delete a #{target} definition by id",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{"id" => %{"type" => "string"}},
        "required" => ["id"]
      }
    }
  end

  defp build_op(:parameter, {:create, type}) do
    %{
      "name" => tool_name(:parameter, {:create, type}),
      "description" => "Create a new #{type} parameter definition",
      "inputSchema" => type_schema(type, :create)
    }
  end

  defp build_op(:parameter, {:update, type}) do
    %{
      "name" => tool_name(:parameter, {:update, type}),
      "description" => "Update a #{type} parameter definition by id",
      "inputSchema" => type_schema(type, :update)
    }
  end

  defp build_op(target, :create) do
    %{
      "name" => tool_name(target, :create),
      "description" => "Create a new #{target} definition",
      "inputSchema" => derived_schema(target, :create)
    }
  end

  defp build_op(target, :update) do
    %{
      "name" => tool_name(target, :update),
      "description" => "Update a #{target} definition by id",
      "inputSchema" => derived_schema(target, :update)
    }
  end

  defp build_op(:arke, :add_parameter) do
    %{
      "name" => tool_name(:arke, :add_parameter),
      "description" => "Associate a parameter to an arke",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "arke_id"      => %{"type" => "string"},
          "parameter_id" => %{"type" => "string"},
          "metadata"     => %{"type" => "object"}
        },
        "required" => ["arke_id", "parameter_id"]
      }
    }
  end

  defp build_op(:arke, :remove_parameter) do
    %{
      "name" => tool_name(:arke, :remove_parameter),
      "description" => "Remove a parameter from an arke",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "arke_id"      => %{"type" => "string"},
          "parameter_id" => %{"type" => "string"}
        },
        "required" => ["arke_id", "parameter_id"]
      }
    }
  end

  defp derived_schema(target, :create) do
    params = parameters_for(target)
    properties = Map.put(build_properties(params), "id", %{"type" => "string"})
    required = ["id" | required_fields(params) -- ["id"]]

    %{"type" => "object", "properties" => properties, "required" => required}
  end

  defp derived_schema(target, :update) do
    params = parameters_for(target)
    properties = Map.merge(%{"id" => %{"type" => "string"}}, build_properties(params))

    %{"type" => "object", "properties" => properties, "required" => ["id"]}
  end

  defp type_schema(type, op) do
    params = parameters_for(type)
    properties = Map.put(build_properties(params), "id", %{"type" => "string"})

    case op do
      :create ->
        required = ["id" | required_fields(params) -- ["id"]]
        %{"type" => "object", "properties" => properties, "required" => required}

      :update ->
        %{"type" => "object", "properties" => properties, "required" => ["id"]}
    end
  end

  defp parameters_for(target) do
    case ArkeManager.get(target, :arke_system) do
      nil  -> []
      arke -> ArkeManager.get_parameters(arke)
    end
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
