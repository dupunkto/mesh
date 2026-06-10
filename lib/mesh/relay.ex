defmodule Mesh.Relay do
  @moduledoc false
  use GenServer

  alias Mesh.Store

  require Logger

  @timeout :timer.seconds(5)

  def start_link(peers) do
    GenServer.start_link(__MODULE__, peers, name: __MODULE__)
  end

  def poll_complete(peer) do
    GenServer.cast(__MODULE__, {:poll_complete, peer})
  end

  @impl true
  def init(peers) do
    {:ok, %{peers: peers, completed: MapSet.new()}}
  end

  @impl true
  def handle_cast({:poll_complete, peer}, state) do
    completed = MapSet.put(state.completed, peer)

    if MapSet.size(completed) == length(state.peers) do
      post_to_all(state.peers)
      {:noreply, %{state | completed: MapSet.new()}}
    else
      {:noreply, %{state | completed: completed}}
    end
  end

  defp post_to_all(peers) do
    secret = Application.fetch_env!(:mesh, :relay_secret)
    body = %{node: Mesh.me(), peers: Store.all()}
    active = Enum.reject(peers, fn peer -> match?(%{status: :down}, Store.get(peer)) end)

    Enum.each(active, fn peer ->
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
    end)
  end
end
