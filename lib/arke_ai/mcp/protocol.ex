defmodule ArkeAi.Mcp.Protocol do
  @moduledoc "Pure JSON-RPC 2.0 dispatch. Takes a decoded params map, returns a tagged tuple."
  @method_not_found -32601

  alias Arke.Core.Unit
  alias Arke.StructManager
  alias ArkeAi.Mcp.Tools.Registry

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
             "name" => server_name(opts),
             "version" => server_version(opts)
           }
         }}

      %{"method" => "tools/list", "id" => _id} ->
        tools = Registry.list_tools(opts[:project], opts[:member], opts[:auth], opts[:expose] || [])
        {:ok, %{"tools" => tools}}

      %{"method" => "tools/call", "id" => _id, "params" => params} ->
        name = params["name"]
        args = params["arguments"] || %{}

        case Registry.call_tool(name, args, opts[:project], opts[:member], opts[:auth], opts[:expose] || []) do
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

  defp server_name(opts) do
    cond do
      opts[:name]    -> to_string(opts[:name])
      opts[:otp_app] -> to_string(opts[:otp_app])
      true           -> "arke_ai"
    end
  end

  defp server_version(opts) do
    cond do
      opts[:version] -> to_string(opts[:version])
      opts[:otp_app] -> app_version(opts[:otp_app]) || "0.1.0"
      true           -> "0.1.0"
    end
  end

  defp app_version(otp_app) do
    case :application.get_key(otp_app, :vsn) do
      {:ok, vsn} -> List.to_string(vsn)
      _          -> nil
    end
  end

  defp format(value) when is_binary(value), do: value
  defp format(%Unit{} = unit), do: Jason.encode!(StructManager.encode(unit))
  defp format([%Unit{} | _] = units), do: Jason.encode!(StructManager.encode(units))
  defp format(value), do: Jason.encode!(value)
end
