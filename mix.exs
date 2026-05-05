defmodule ArkeAi.MixProject do
  use Mix.Project

  def project do
    [
      app: :arke_ai,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.16", optional: true},
      {:jason, "~> 1.4", optional: true},
      {:arke, "~> 0.6.1"},
      {:arke_auth, "~> 0.4.4"}
    ]
  end
end
