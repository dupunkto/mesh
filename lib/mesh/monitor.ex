defmodule Mesh.Monitor do
  @moduledoc false
  use GenServer

  alias Mesh.Store
  alias Mesh.Notifier

  require Logger

  @interval :timer.seconds(5)
  @timeout :timer.seconds(5)
  @threshold 4 # send down notification after 3 missed pings

  def start_link(peer) do
    GenServer.start_link(__MODULE__, peer)
  end

  @impl true
  def init(peer) do
    schedule(0)
    {:ok, peer}
  end

  @impl true
  def handle_info(:poll, peer) do
    case ping(peer) do
      :ok -> on_success(peer)
      {:error, reason} -> on_failure(peer, reason)
    end

    schedule(@interval)
    {:noreply, peer}
  end

  defp ping(peer) do
    case Req.get("https://#{peer}/ping", receive_timeout: @timeout, retry: false) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: status}} -> {:error, {:http, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp on_success(peer) do
    now = DateTime.utc_now()
    current = Store.get(peer)

    case current.status do
      :up ->
        Store.put(peer, %{current | last_seen: now, consecutive_failures: 0})

      :down ->
        Store.put(peer, %{
          status: :up,
          since: now,
          last_seen: now,
          consecutive_failures: 0
        })

        Notifier.notify(peer, :up)

      :unknown ->
        Store.put(peer, %{
          status: :up,
          since: now,
          last_seen: now,
          consecutive_failures: 0
        })
    end
  end

  defp on_failure(peer, reason) do
    now = DateTime.utc_now()
    state = Store.get(peer)
    failures = state.consecutive_failures + 1

    Logger.warning("ping #{peer} failed: #{inspect(reason)} (#{failures}/#{@threshold})")

    if failures >= @threshold and state.status != :down do
      Store.put(peer, %{state | status: :down, since: now, consecutive_failures: failures})
      Notifier.notify(peer, :down)
    else
      Store.put(peer, %{state | consecutive_failures: failures})
    end
  end

  defp schedule(delay) do
    Process.send_after(self(), :poll, delay)
  end
end