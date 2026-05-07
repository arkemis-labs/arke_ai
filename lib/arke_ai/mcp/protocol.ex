defmodule ArkeAi.Mcp.Protocol do
  @moduledoc "Pure JSON-RPC 2.0 dispatch. Takes a decoded params map, returns a tagged tuple."
  @method_not_found -32601

  alias Arke.Core.Unit
  alias Arke.StructManager
  alias ArkeAi.Mcp.ToolRegistry

  def handle(body, _session_id, opts \\ []) do
    case body do
      %{"id" => nil} ->
        {:notification, nil}

      body when not is_map_key(body, "id") ->
        {:notification, nil}

      %{"method" => "initialize", "id" => _id} ->
        {:ok,
         %{
           "capabilities" => %{"tools" => %{"listChanged" => true}},
           "protocolVersion" => opts[:protocol_version] || "2025-03-26",
           "serverInfo" => %{
             "name" => opts[:name] || "arke_ai",
             "version" => opts[:version] || "0.1.0"
           }
         }}

      %{"method" => "tools/list", "id" => _id} ->
        tools = ToolRegistry.list_tools(opts[:project], opts[:member], opts[:auth], opts[:expose] || [])
        {:ok, %{"tools" => tools}}

      %{"method" => "tools/call", "id" => _id, "params" => params} ->
        name = params["name"]
        args = params["arguments"] || %{}

        case ToolRegistry.call_tool(name, args, opts[:project], opts[:member], opts[:auth], opts[:expose] || []) do
          {:ok, result} ->
            {:ok, %{"content" => [%{"type" => "text", "text" => format(result)}]}}

          {:error, reason} ->
            {:ok,
             %{
               "content" => [%{"type" => "text", "text" => format(reason)}],
               "isError" => true
             }}
        end

      _ ->
        {:error, @method_not_found, "method not found"}
    end
  end

  defp format(value) when is_binary(value), do: value
  defp format(%Unit{} = unit), do: Jason.encode!(StructManager.encode(unit))
  defp format([%Unit{} | _] = units), do: Jason.encode!(StructManager.encode(units))
  defp format(value), do: Jason.encode!(value)
end
