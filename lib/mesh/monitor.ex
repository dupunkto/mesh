defmodule Mesh.Monitor do
  @moduledoc false
  use GenServer

  alias Mesh.Store
  alias Mesh.Notifier

  require Logger

  @poll_interval :timer.seconds(5)

  @followup_intervals [
    :timer.minutes(15),
    :timer.minutes(30),
    :timer.hours(1),
    :timer.hours(2),
    :timer.hours(5)
  ]

  def poll_interval, do: @poll_interval
  def followup_intervals, do: @followup_intervals

  @timeout :timer.seconds(5)
  def timeout, do: @timeout

  @threshold 9 # send down notification after 9 missed pings
  def threshold, do: @threshold

  def start_link(peer) do
    GenServer.start_link(__MODULE__, peer)
  end

  @impl true
  def init(peer) do
    schedule_poll(0)
    {:ok, {peer, 0}}
  end

  @impl true
  def handle_info(:poll, {peer, step}) do
    step =
      case ping(peer) do
        :ok -> on_success(peer, step)
        {:error, reason} -> on_failure(peer, reason, step)
      end

    schedule_poll(@poll_interval)
    {:noreply, {peer, step}}
  end

  @impl true
  def handle_info(:followup, {peer, step}) do
    step = on_followup(peer, step)
    {:noreply, {peer, step}}
  end

  defp ping(peer) do
    opts = [
      receive_timeout: @timeout,
      retry: false,
      finch: Mesh.Finch
    ]

    case Req.get("https://#{peer}/ping", opts) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: status}} -> {:error, {:http, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp on_success(peer, step) do
    now = DateTime.utc_now()
    current = Store.get(peer)

    case current.status do
      :up ->
        Store.put_status(peer, %{current | last_seen: now, consecutive_failures: 0})
        step

      :down ->
        downtime_since = current.since

        Store.put_status(peer, %{
          status: :up,
          since: now,
          last_seen: now,
          consecutive_failures: 0
        })

        Notifier.notify(peer, :up, downtime_since: downtime_since)
        0

      :unknown ->
        Store.put_status(peer, %{
          status: :up,
          since: now,
          last_seen: now,
          consecutive_failures: 0
        })
        step
    end
  end

  defp on_failure(peer, reason, step) do
    now = DateTime.utc_now()
    state = Store.get(peer)
    failures = state.consecutive_failures + 1

    Logger.warning("ping #{peer} failed: #{inspect(reason)} (#{failures}/#{@threshold})")

    if failures >= @threshold and state.status != :down do
      Store.put_status(peer, %{state | status: :down, since: now, consecutive_failures: failures})
      Notifier.notify(peer, :down)
      schedule_followup(Enum.at(@followup_intervals, 0))
      0
    else
      Store.put_status(peer, %{state | consecutive_failures: failures})
      step
    end
  end

  defp on_followup(peer, step) do
    if Store.get(peer).status == :down do
      Notifier.notify(peer, :still_down)
      next_step = min(step + 1, length(@followup_intervals) - 1)
      schedule_followup(Enum.at(@followup_intervals, next_step))
      next_step
    else
      step
    end
  end

  defp schedule_poll(delay) do
    Process.send_after(self(), :poll, delay)
  end

  defp schedule_followup(delay) do
    Process.send_after(self(), :followup, delay)
  end
end
