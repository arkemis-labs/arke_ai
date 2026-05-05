defmodule ArkeAi.Mcp.Protocol do
  @moduledoc "Pure JSON-RPC 2.0 dispatch. Takes a decoded params map, returns a tagged tuple."
  @method_not_found -32601

  def handle(body, _session_id, opts \\ []) do
    case body do
      %{"id" => nil} ->
        {:notification, nil}

      body when not is_map_key(body, "id") ->
        {:notification, nil}

      %{"method" => "initialize", "id" => _id} ->
        {:ok,
         %{
           "capabilities" => %{"tools" => %{}},
           "protocolVersion" => opts[:protocol_version] || "2025-03-26",
           "serverInfo" => %{
             # todo: override
             "name" => "arke_ai",
             "version" => "0.1.0"
           }
         }}

      %{"method" => "tools/list", "id" => _id} ->
        {:ok,
         %{
           "tools" => [
             %{
               "name" => "test",
               "description" => "test_description",
               "inputSchema" => %{"type" => "object", "properties" => %{}, "required" => []}
             }
           ]
         }}

      %{"method" => "tools/call", "id" => _id, "params" => params} ->
        case params["name"] do
          "test" ->
            {:ok, %{"content" => [%{"type" => "text", "text" => "pong from test tool"}]}}

          _ ->
            {:ok,
             %{
               "content" => [%{"type" => "text", "text" => "unknown tool: #{params["name"]}"}],
               "isError" => true
             }}
        end

      _ ->
        {:error, @method_not_found, "method not found"}
    end
  end
end
