defmodule ArkeAi.Mcp.ToolRegistry do
  @moduledoc "Derives MCP tool definitions from Arke ETS on demand and routes calls to the right tools module."

  alias ArkeAi.Mcp.Tools.{ArkeTools, GroupTools, SystemTools}

  def list_tools(project, config) do
    Enum.flat_map(config, &tools_for_entry(&1, project))
  end

  def call_tool(name, args, project, config) do
    case resolve(name, config) do
      nil      -> {:error, "unknown tool"}
      resolved -> dispatch(resolved, args, project)
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

  defp dispatch({:arke, id, op}, args, project),
    do: ArkeTools.execute(id, op, args, project)

  defp dispatch({:group, id, op}, args, project),
    do: GroupTools.execute(id, op, args, project)

  defp dispatch({:system, target, op}, args, project),
    do: SystemTools.execute(target, op, args, project)
end
