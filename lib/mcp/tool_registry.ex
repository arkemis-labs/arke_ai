defmodule ArkeAi.Mcp.ToolRegistry do
  @moduledoc "Derives MCP tool definitions from Arke ETS on demand and routes calls to the right tools module."

  alias ArkeAi.Mcp.Permission
  alias ArkeAi.Mcp.Tools.{ArkeTools, GroupTools, SystemTools}

  @local_permission %{filter: nil, child_only: false, get: true, put: true, post: true, delete: true}

  def list_tools(project, member, auth_mode, config) do
    config
    |> Enum.flat_map(&tools_for_entry(&1, project))
    |> Enum.filter(&authorized?(&1, project, member, auth_mode, config))
  end

  def call_tool(name, args, project, member, auth_mode, config) do
    case resolve(name, config) do
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

  defp tools_for_entry({:arke, id, ops}, project),
    do: ArkeTools.build(id, ops, project)

  defp tools_for_entry({:group, id, ops}, project),
    do: GroupTools.build(id, ops, project)

  defp tools_for_entry({:system, target, ops}, _project),
    do: SystemTools.build(target, ops)

  defp resolve(name, config) do
    Enum.find_value(config, &resolve_entry(&1, name))
  end

  defp resolve_entry({:arke, id, ops}, name) do
    case ArkeTools.resolve(id, ops, name) do
      nil -> nil
      op  -> {:arke, id, op}
    end
  end

  defp resolve_entry({:group, id, ops}, name) do
    case GroupTools.resolve(id, ops, name) do
      nil -> nil
      op  -> {:group, id, op}
    end
  end

  defp resolve_entry({:system, target, ops}, name) do
    case SystemTools.resolve(target, ops, name) do
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

  defp dispatch({:arke, id, op}, args, ctx),       do: ArkeTools.execute(id, op, args, ctx)
  defp dispatch({:group, id, op}, args, ctx),      do: GroupTools.execute(id, op, args, ctx)
  defp dispatch({:system, target, op}, args, ctx), do: SystemTools.execute(target, op, args, ctx)
end
