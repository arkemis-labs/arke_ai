defmodule ArkeAi do
  @moduledoc """
  AI integrations for [Arke](https://hex.pm/packages/arke). Currently exposes the
  `ArkeAi.Mcp.*` namespace for serving an Arke project to MCP-capable agents
  (Claude Desktop, Cursor, IDE integrations) over HTTP / Streamable HTTP.

  ## Installation

  Add `arke_ai` to your `mix.exs`:

      def deps do
        [
          {:arke_ai, "~> 0.1"}
        ]
      end

  ## Mounting in Phoenix

  Mount `ArkeAi.Mcp.Router` as a forward in your Phoenix router:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

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
      end

  ## Configuration

  ### `auth` — required

    * `:local` — IP-restricted to localhost. Trusted dev environment, no per-call permission checks.
      Project resolved from the `arke-project-key` request header, falling back to the `:project` opt.
    * `:bearer` — Guardian JWT verification via `ArkeAuth.Guardian`. Project and member extracted
      from the token. Per-call permission checks via `ArkeAuth.Utils.Permission` enforce op gates
      and row-level filter scoping.

  ### `expose` — required

  A list of `{type, id, ops}` tuples declaring which arkes / groups / system operations are visible
  to the agent. Each `ops` list is validated against the type's allowed ops.

  | Type | Valid ops |
  |---|---|
  | `:arke` | `:list`, `:get`, `:search`, `:create`, `:update`, `:delete` |
  | `:group` | `:list`, `:get`, `:search`, `:list_arkes`, `:get_schema`, `:add_arke`, `:remove_arke` |
  | `{:system, :arke}` | `:list`, `:get`, `:create`, `:update`, `:delete`, `:add_parameter`, `:remove_parameter` |
  | `{:system, :parameter}` | `:list`, `:get`, `:create`, `:update`, `:delete` |
  | `{:system, :group}` | `:list`, `:get`, `:create`, `:update`, `:delete` |

  System ops default to deny — only `super_admin` members can access them unless permission link
  units are explicitly seeded for other roles.

  Pass `expose: :unsafe_all` instead of a list to expose every op above for every arke and group
  of the project, re-read on each request so arkes created at runtime appear immediately. Only
  allowed with `auth: :local`; the router raises otherwise.

  ### `otp_app` — optional

  Used to derive `serverInfo.name` and `serverInfo.version` returned during `initialize`. If absent,
  defaults to `"arke_ai"` and `"0.1.0"`. Override individually with `:name` and `:version`.

  ### `project` — required for `:local`

  An atom matching an existing `:arke_project` id in `:arke_system`. Ignored for `:bearer` (project
  comes from the JWT).

  ## Transport

  `ArkeAi.Mcp.Router` implements MCP's [Streamable HTTP transport](https://modelcontextprotocol.io/specification/2025-03-26/basic/transports#streamable-http):

    * `POST /mcp` — JSON-RPC request/response
    * `GET /mcp` with `Accept: text/event-stream` — Server-Sent Events stream for `notifications/tools/list_changed`
    * `mcp-session-id` response header echoed by the client

  Server pushes `notifications/tools/list_changed` after schema mutations
  (`:add_parameter`, `:create_*_parameter`, `:create_arke`, etc.) so connected agents refresh
  their cached tool lists.

  Stdio is not supported directly — bridge via [`mcp-remote`](https://www.npmjs.com/package/mcp-remote)
  for clients that only speak stdio.
  """
end
