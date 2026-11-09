defmodule ArkeAi.Mcp.Tools.Registry do
  @moduledoc "Derives MCP tool definitions from Arke ETS on demand and routes calls to the right tools module."

  alias Arke.Boundary.{ArkeManager, GroupManager}
  alias ArkeAi.Mcp.Permission
  alias ArkeAi.Mcp.Tools

  @local_permission %{filter: nil, child_only: false, get: true, put: true, post: true, delete: true}

  @arke_ops [:list, :get, :search, :create, :update, :delete]
  @group_ops [:list, :get, :search, :list_arkes, :get_schema, :add_arke, :remove_arke]
  @system_ops [
    arke: [:list, :get, :create, :update, :delete, :add_parameter, :remove_parameter],
    parameter: [:list, :get, :create, :update, :delete],
    group: [:list, :get, :create, :update, :delete]
  ]

  def list_tools(project, member, auth_mode, config) do
    config = expand(config, project)

    config
    |> Enum.flat_map(&tools_for_entry(&1, project))
    |> Enum.filter(&authorized?(&1, project, member, auth_mode, config))
  end

  def call_tool(name, args, project, member, auth_mode, config) do
    case resolve(name, expand(config, project)) do
      nil ->
        {:error, "unknown tool"}

      {type, id, op} = resolved ->
        case authorize(type, id, op, project, member, auth_mode) do
          {:ok, permission} ->
            ctx = %{project: project, member: member, permission: permission}
            dispatch(resolved, args, ctx)

          {:error, :forbidden} ->
            {:error, "forbidden"}
        end
    end
  end

  # Re-read from ETS per request so arkes/groups created at runtime show up immediately.
  defp expand(:unsafe_all, project) do
    system = for {target, ops} <- @system_ops, do: {:system, target, ops}
    arkes = for {id, _} <- ArkeManager.get_all(project), do: {:arke, id, @arke_ops}
    groups = for {id, _} <- GroupManager.get_all(project), do: {:group, id, @group_ops}
    system ++ arkes ++ groups
  end

  defp expand(config, _project), do: config

  defp tools_for_entry({:arke, id, ops}, project),
    do: Tools.Arke.build(id, ops, project)

  defp tools_for_entry({:group, id, ops}, project),
    do: Tools.Group.build(id, ops, project)

  defp tools_for_entry({:system, target, ops}, _project),
    do: Tools.System.build(target, ops)

  defp resolve(name, config) do
    Enum.find_value(config, &resolve_entry(&1, name))
  end

  defp resolve_entry({:arke, id, ops}, name) do
    case Tools.Arke.resolve(id, ops, name) do
      nil -> nil
      op  -> {:arke, id, op}
    end
  end

  defp resolve_entry({:group, id, ops}, name) do
    case Tools.Group.resolve(id, ops, name) do
      nil -> nil
      op  -> {:group, id, op}
    end
  end

  defp resolve_entry({:system, target, ops}, name) do
    case Tools.System.resolve(target, ops, name) do
      nil -> nil
      op  -> {:system, target, op}
    end
  end

  defp authorize(_type, _id, _op, _project, _member, :local), do: {:ok, @local_permission}

  defp authorize(type, id, op, project, member, _auth_mode) do
    Permission.check(permission_target(type, id, op), op, project, member)
  end

  defp authorized?(_tool, _project, _member, :local, _config), do: true

  defp authorized?(tool, project, member, _auth_mode, config) do
    case resolve(tool["name"], config) do
      nil -> true
      {type, id, op} ->
        match?({:ok, _}, Permission.check(permission_target(type, id, op), op, project, member))
    end
  end

  defp permission_target(:arke, id, _op),                    do: id
  defp permission_target(:group, id, _op),                   do: id
  defp permission_target(:system, _target, {:create, type}), do: type
  defp permission_target(:system, _target, {:update, type}), do: type
  defp permission_target(:system, target, _op),              do: target

  defp dispatch({:arke, id, op}, args, ctx),       do: Tools.Arke.execute(id, op, args, ctx)
  defp dispatch({:group, id, op}, args, ctx),      do: Tools.Group.execute(id, op, args, ctx)
  defp dispatch({:system, target, op}, args, ctx), do: Tools.System.execute(target, op, args, ctx)
end
