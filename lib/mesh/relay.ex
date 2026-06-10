defmodule Mesh.Relay do
  @moduledoc false
  use GenServer

  alias Mesh.Store

  require Logger

  @interval :timer.seconds(5)
  @timeout :timer.seconds(5)

  def start_link(peer) do
    GenServer.start_link(__MODULE__, peer)
  end

  @impl true
  def init(peer) do
    schedule(@interval)
    {:ok, peer}
  end

  @impl true
  def handle_info(:relay, peer) do
    unless match?(%{status: :down}, Store.get(peer)) do
      secret = Application.fetch_env!(:mesh, :relay_secret)
      body = %{node: Mesh.me(), peers: Store.peers()}

      Task.start(fn ->
        case Req.post("https://#{peer}/relay",
               json: body,
               headers: [authorization: secret],
               receive_timeout: @timeout,
               retry: false
             ) do
          {:ok, %{status: status}} when status in 200..299 -> :ok
          {:ok, %{status: status}} -> Logger.debug("relay to #{peer} rejected: HTTP #{status}")
          {:error, reason} -> Logger.debug("relay to #{peer} failed: #{inspect(reason)}")
        end
      end)
    end

    schedule(@interval)
    {:noreply, peer}
  end

  defp schedule(delay) do
    Process.send_after(self(), :relay, delay)
  end
end
