defmodule ArkeAi.Mcp.Router do
  @moduledoc "HTTP entry point for the MCP server. Accepts JSON-RPC 2.0 over POST, enforces auth, delegates to Protocol."
  use Plug.Router, copy_opts_to_assign: :router_opts

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  plug(ArkeAi.Mcp.Plugs.Auth)
  plug(:match)
  plug(:dispatch)

  post "/" do
    session_id = ensure_session_id(conn)
    opts = request_opts(conn)

    conn = put_resp_header(conn, "mcp-session-id", session_id)

    case ArkeAi.Mcp.Protocol.handle(conn.params, session_id, opts) do
      {:ok, result} -> respond(conn, result)
      {:notification, _} -> respond_notification(conn)
      {:error, code, message} -> respond_error(conn, code, message)
    end
  end

  get "/" do
    accept_header = get_req_header(conn, "accept")

    if Enum.any?(accept_header, &String.contains?(&1, "text/event-stream")) do
      ArkeAi.Mcp.SSE.serve(conn, request_opts(conn))
    else
      send_resp(conn, 400, "GET requires Accept: text/event-stream")
    end
  end

  match _ do
    send_resp(conn, 405, "Method not allowed")
  end

  defp request_opts(conn) do
    conn.assigns.router_opts
    |> Keyword.put(:project, conn.assigns[:arke_project])
    |> Keyword.put(:member, conn.assigns[:arke_member])
  end

  defp ensure_session_id(conn) do
    case get_req_header(conn, "mcp-session-id") do
      [session_id | _] -> session_id
      [] -> generate_session_id()
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp respond(conn, result) do
    body =
      %{"jsonrpc" => "2.0", "id" => conn.params["id"], "result" => result}
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end

  defp respond_notification(conn) do
    send_resp(conn, 202, "")
  end

  defp respond_error(conn, code, message) do
    body =
      %{
        "jsonrpc" => "2.0",
        "id" => conn.params["id"],
        "error" => %{"code" => code, "message" => message}
      }
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, body)
  end
end
