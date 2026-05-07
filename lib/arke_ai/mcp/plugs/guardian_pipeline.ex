defmodule ArkeAi.Mcp.Plugs.GuardianPipeline do
  @moduledoc "Guardian plug pipeline for Bearer token verification using ArkeAuth.Guardian."
  use Guardian.Plug.Pipeline,
    otp_app: :arke_auth,
    module: ArkeAuth.Guardian,
    error_handler: ArkeAi.Mcp.Plugs.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
