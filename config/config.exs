import Config

config :heartbeat, :endpoints, [
  %{
    name: "GitHub",
    url: "https://www.githubstatus.com/api/v2/status.json",
    interval: 10_000
  },
  %{
    name: "Google",
    url: "https://www.google.com",
    interval: 15_000
  },
  %{
    name: "My API",
    url: "http://localhost:4000/health",
    interval: 5_000
  }
]
