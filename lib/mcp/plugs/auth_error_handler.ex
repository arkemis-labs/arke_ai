defmodule ArkeAi.Mcp.Plugs.AuthErrorHandler do
  @moduledoc "Guardian error handler for the MCP pipeline. Returns 401 on any auth failure."
  import Plug.Conn

  def auth_error(conn, _reason, _opts) do
    conn |> send_resp(401, "Unauthorized") |> halt()
  end
end
