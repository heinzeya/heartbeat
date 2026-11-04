defmodule Heartbeat.Worker do
  use Task, restart: :permanent

  require Logger

  def start_link(endpoint) do
    Task.start_link(__MODULE__, :run, [endpoint])
  end

  def run(endpoint) do
    Logger.info("Starting monitor: #{endpoint.name}")

    loop(endpoint)
  end

  defp loop(endpoint) do
    check(endpoint)

    Process.sleep(endpoint.interval)
    loop(endpoint)
  end

  defp check(endpoint) do
    started = System.monotonic_time(:millisecond)

    result =
      Req.get(endpoint.url,
        retry: false,
        receive_timeout: 5_000
      )

    duration =
      System.monotonic_time(:millisecond) - started

    case result do
      {:ok, %{status: status}}
      when status >= 200 and status < 300 ->
        Logger.info(
          "[#{endpoint.name}] UP " <>
            "HTTP #{status} (#{duration}ms)"
        )

      {:ok, %{status: status}} ->
        Logger.warning(
          "[#{endpoint.name}] DOWN " <>
            "HTTP #{status} (#{duration}ms)"
        )

      {:error, reason} ->
        Logger.error(
          "[#{endpoint.name}] ERROR " <>
            inspect(reason)
        )
    end
  end
end
