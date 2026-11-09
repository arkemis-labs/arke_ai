# ArkeAi

[![Hex.pm](https://img.shields.io/hexpm/v/arke_ai.svg)](https://hex.pm/packages/arke_ai)
[![Documentation](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/arke_ai)
[![License](https://img.shields.io/hexpm/l/arke_ai.svg)](https://github.com/arkemis-labs/arke_ai/blob/main/LICENSE)

AI integrations for [Arke](https://hex.pm/packages/arke). Exposes an Arke project to
MCP-capable agents (Claude Desktop, Cursor, IDE integrations) over Streamable HTTP.

## Installation

Add `arke_ai` to your `mix.exs`:

```elixir
def deps do
  [
    {:arke_ai, "~> 0.1"}
  ]
end
```

## Quick start

Mount `ArkeAi.Mcp.Router` in your Phoenix router:

```elixir
forward "/mcp", ArkeAi.Mcp.Router,
  auth: :local,
  project: :my_project,
  otp_app: :my_app,
  expose: [
    {:arke,   :car,       [:list, :get, :search, :create, :update, :delete]},
    {:group,  :vehicle,   [:list, :get, :search, :list_arkes, :get_schema, :add_arke, :remove_arke]},
    {:system, :arke,      [:list, :get, :create, :update, :delete, :add_parameter, :remove_parameter]},
    {:system, :parameter, [:list, :get, :create, :update, :delete]},
    {:system, :group,     [:list, :get, :create, :update, :delete]}
  ]
```

Connect any MCP client to `http://localhost:4000/mcp`.

For local development, `expose: :unsafe_all` exposes every op for every arke and group in the
project, plus all system ops (only allowed with `auth: :local`).

## Auth modes

- `:local` — IP-restricted to localhost. Trusted dev environment, no permission checks.
- `:bearer` — Guardian JWT verification. Per-call permission gate + row-level filter scoping
  via `ArkeAuth.Utils.Permission`. Project and member extracted from the token.

## Transport

Implements MCP's [Streamable HTTP transport](https://modelcontextprotocol.io/specification/2025-03-26/basic/transports#streamable-http):

- `POST /mcp` — JSON-RPC request/response
- `GET /mcp` with `Accept: text/event-stream` — SSE stream for server-pushed
  `notifications/tools/list_changed` after schema mutations

Stdio is not supported directly — bridge with [`mcp-remote`](https://www.npmjs.com/package/mcp-remote)
for stdio-only clients.

## Documentation

Full configuration, op tables per type, and protocol details:
**[hexdocs.pm/arke_ai](https://hexdocs.pm/arke_ai)**.

## License

Apache 2.0. See [LICENSE](LICENSE).
