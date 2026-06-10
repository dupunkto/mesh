defmodule Mesh.Store do
  @moduledoc false
  use GenServer

  @type state :: %{
          peers: %{String.t() => peer_state()},
          relays: %{
            String.t() => %{
              received_at: DateTime.t(),
              peers: %{String.t() => peer_state()}
            }
          }
        }

  @type peer_state :: %{
          status: :unknown | :up | :down,
          since: DateTime.t(),
          last_seen: DateTime.t() | nil,
          consecutive_failures: non_neg_integer()
        }

  def start_link(peers) do
    GenServer.start_link(__MODULE__, peers, name: __MODULE__)
  end

  @spec peers() :: %{String.t() => peer_state()}
  def peers() do
    GenServer.call(__MODULE__, :peers)
  end

  @spec relays() :: %{String.t() => peer_state()}
  def relays do
    GenServer.call(__MODULE__, :relays)
  end

  @spec get(String.t()) :: peer_state() | nil
  def get(peer) do
    GenServer.call(__MODULE__, {:get, peer})
  end

  @spec put_status(String.t(), peer_state()) :: :ok
  def put_status(peer, state) do
    GenServer.cast(__MODULE__, {:put_status, peer, state})
  end

  @spec put_relay(String.t(), map()) :: :ok
  def put_relay(from_peer, peers) do
    GenServer.cast(__MODULE__, {:put_relay, from_peer, peers})
  end

  @doc false
  @impl true
  def init(peers) do
    now = DateTime.utc_now()

    peers = 
      Map.new(peers, fn peer ->
        {peer, %{status: :unknown, since: now, last_seen: nil, consecutive_failures: 0}}
      end)

    {:ok, %{peers: peers, relays: %{}}}
  end

  @doc false
  @impl true
  def handle_call(:peers, _from, state) do
    {:reply, state.peers, state}
  end

  @doc false
  @impl true
  def handle_call(:relays, _from, state) do
    {:reply, state.relays, state}
  end

  @doc false
  @impl true
  def handle_call({:get, peer}, _from, state) do
    {:reply, Map.get(state.peers, peer), state}
  end

  @doc false
  @impl true
  def handle_cast({:put_status, peer, peer_state}, state) do
    {:noreply, put_in(state, [:peers, peer], peer_state)}
  end

  @doc false
  @impl true
  def handle_cast({:put_relay, from_peer, peers}, state) do
    entry = %{received_at: DateTime.utc_now(), peers: peers}
    {:noreply, put_in(state, [:relays, from_peer], entry)}
  end
end
