defmodule Heartbeat.MixProject do
  use Mix.Project

  def project do
    [
      app: :heartbeat,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Heartbeat.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"}
    ]
  end
end
