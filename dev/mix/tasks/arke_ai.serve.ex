defmodule Mix.Tasks.ArkeAi.Serve do
  use Mix.Task

  @shortdoc "Starts a local MCP server for testing"

  def run(_args) do
    Application.ensure_all_started(:bandit)
    {:ok, _} = Bandit.start_link(plug: ArkeAi.Mcp.Router, port: 4001)
    Mix.shell().info("ArkeAI MCP server running at http://localhost:4001/mcp")
    Process.sleep(:infinity)
  end
end
