defmodule Heartbeat.Application do
  use Application

  @impl true
  def start(_type, _args) do
    endpoints =
      Application.fetch_env!(:heartbeat, :endpoints)

    children =
      Enum.map(endpoints, fn endpoint ->
        Supervisor.child_spec(
          {Heartbeat.Worker, endpoint},
          id: {:heartbeat, endpoint.name}
        )
      end)

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: Heartbeat.Supervisor
    )
  end
end
