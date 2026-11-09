defmodule ArkeAi.MixProject do
  use Mix.Project

  @version "0.2.0"
  @scm_url "https://github.com/arkemis-labs/arke_ai"
  @site_url "https://arkehub.com"

  def project do
    [
      app: :arke_ai,
      name: "ArkeAi",
      version: @version,
      elixir: "~> 1.16",
      source_url: @scm_url,
      homepage_url: @site_url,
      description: description(),
      package: package(),
      docs: [main: "ArkeAi"],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ArkeAi.Application, []}
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.16", optional: true},
      {:jason, "~> 1.4", optional: true},
      {:arke, "~> 0.6.1"},
      {:arke_auth, "~> 0.4.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "AI integrations for Arke. Exposes an Arke project to MCP-capable agents over Streamable HTTP."
  end

  defp package do
    [
      name: "arke_ai",
      licenses: ["Apache-2.0"],
      links: %{
        "Website" => @site_url,
        "Github" => @scm_url
      }
    ]
  end
end
