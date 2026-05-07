defmodule ArkeAi.Application do
  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: ArkeAi.Supervisor]

    children = [
      %{id: :arke_ai_mcp_pubsub, start: {:pg, :start_link, [:arke_ai_mcp_pubsub]}}
    ]

    Supervisor.start_link(children, opts)
  end
end
