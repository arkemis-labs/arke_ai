defmodule ArkeAi.Mcp.Router do
  @moduledoc "HTTP entry point for the MCP server. Accepts JSON-RPC 2.0 over POST, enforces auth, delegates to Protocol."
  use Plug.Router, copy_opts_to_assign: :router_opts

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  plug ArkeAi.Mcp.Plugs.Auth
  plug(:match)
  plug(:dispatch)

  post "/" do
    session_id = get_session_id(conn)

    opts =
      conn.assigns.router_opts
      |> Keyword.put(:project, conn.assigns[:arke_project])

    case ArkeAi.Mcp.Protocol.handle(conn.params, session_id, opts) do
      {:ok, result} -> respond(conn, result)
      {:notification, _} -> respond_notification(conn)
      {:error, code, message} -> respond_error(conn, code, message)
    end
  end

  match _ do
    send_resp(conn, 405, "Method not allowed")
  end

  defp get_session_id(conn) do
    case get_req_header(conn, "mcp-session-id") do
      [session_id | _] -> session_id
      [] -> nil
    end
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
