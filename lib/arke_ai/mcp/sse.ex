defmodule ArkeAi.Mcp.SSE do
  @moduledoc """
  SSE transport: opens a chunked response, subscribes to notifications, writes
  events.
  """

  import Plug.Conn
  alias ArkeAi.Mcp.Notifications

  def serve(conn, opts) do
    project = opts[:project]

    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> send_chunked(200)

    Notifications.subscribe(project)
    loop(conn)
  end

  defp loop(conn) do
    receive do
      {:mcp_notification, payload} ->
        case write_event(conn, payload) do
          {:ok, conn} -> loop(conn)
          {:error, _} -> conn
        end
    after
      30_000 ->
        case write_keepalive(conn) do
          {:ok, conn} -> loop(conn)
          {:error, _} -> conn
        end
    end
  end

  defp write_event(conn, payload),
    do: chunk(conn, ["event: message\n", "data: ", Jason.encode!(payload), "\n\n"])

  defp write_keepalive(conn), do: chunk(conn, ": ping\n\n")

end
