defmodule Mesh.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # HTTP2 reuses connections, which caused us to *not* detect downtime
    # because the existing connection stayed intact. So HTTP1 it is.
    idle_time = Mesh.Monitor.poll_interval() - :timer.seconds(1)
    pools = %{default: [protocol: :http1, pool_max_idle_time: idle_time]}

    children =
      [
        MeshWeb.Telemetry,
        {Finch, name: Mesh.Finch, pools: pools},
        {Phoenix.PubSub, name: Mesh.PubSub},
        MeshWeb.Endpoint,
        {Mesh.Store, peers()}
      ]

    opts = [strategy: :one_for_one, name: Mesh.Supervisor]
    Supervisor.start_link(children ++ monitors() ++ relays(), opts)
  end

  defp peers do
    Application.get_env(:mesh, :peers, [])
  end

  defp monitors do
    Enum.map(peers(), fn peer ->
      Supervisor.child_spec({Mesh.Monitor, peer}, id: {Mesh.Monitor, peer})
    end)
  end

  defp relays do
    if Application.get_env(:mesh, :relay_secret) do
      Enum.map(peers(), fn peer ->
        Supervisor.child_spec({Mesh.Relay, peer}, id: {Mesh.Relay, peer})
      end)
    else
      []
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    MeshWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
