defmodule Mesh.Store do
  @moduledoc false
  use GenServer

  @type state :: %{
          status: :unknown | :up | :down,
          since: DateTime.t(),
          last_seen: DateTime.t() | nil,
          consecutive_failures: non_neg_integer()
        }

  def start_link(peers) do
    GenServer.start_link(__MODULE__, peers, name: __MODULE__)
  end

  @spec all() :: %{String.t() => state()}
  def all do
    GenServer.call(__MODULE__, :all)
  end

  @spec get(String.t()) :: state() | nil
  def get(peer) do
    GenServer.call(__MODULE__, {:get, peer})
  end

  @spec put(String.t(), state()) :: :ok
  def put(peer, state) do
    GenServer.cast(__MODULE__, {:put, peer, state})
  end

  @spec put_relay(String.t(), map()) :: :ok
  def put_relay(from, peers) do
    GenServer.cast(__MODULE__, {:put_relay, from, peers})
  end

  @spec all_relays() :: map()
  def all_relays do
    GenServer.call(__MODULE__, :all_relays)
  end

  @doc false
  @impl true
  def init(peers) do
    now = DateTime.utc_now()

    {:ok,
     %{
       peers:
         Map.new(peers, fn peer ->
           {peer, %{status: :unknown, since: now, last_seen: nil, consecutive_failures: 0}}
         end),
       received: %{}
     }}
  end

  @doc false
  @impl true
  def handle_call(:all, _from, state) do
    {:reply, state.peers, state}
  end

  @doc false
  @impl true
  def handle_call(:all_relays, _from, state) do
    {:reply, state.received, state}
  end

  @doc false
  @impl true
  def handle_call({:get, peer}, _from, state) do
    {:reply, Map.get(state.peers, peer), state}
  end

  @doc false
  @impl true
  def handle_cast({:put, peer, peer_state}, state) do
    {:noreply, put_in(state, [:peers, peer], peer_state)}
  end

  @doc false
  @impl true
  def handle_cast({:put_relay, from, peers}, state) do
    entry = %{received_at: DateTime.utc_now(), peers: peers}
    {:noreply, put_in(state, [:received, from], entry)}
  end
end
