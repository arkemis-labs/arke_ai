defmodule ArkeAi.Mcp.Notifications do
  @moduledoc """
  Distributed pub/sub for MCP notifications via :pg.
  """

  @scope :arke_ai_mcp_pubsub

  def subscribe(project) do
    :pg.join(@scope, {:arke_ai, project}, self())
  end

  def tools_list_changed(project) do
    msg = %{"jsonrpc" => "2.0", "method" => "notifications/tools/list_changed"}

    :pg.get_members(@scope, {:arke_ai, project})
    |> Enum.each(&send(&1, {:mcp_notification, msg}))
  end
end
