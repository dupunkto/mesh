defmodule Mesh.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        MeshWeb.Telemetry,
        {Phoenix.PubSub, name: Mesh.PubSub},
        MeshWeb.Endpoint,
        {Mesh.Store, peers()}
      ]

    opts = [strategy: :one_for_one, name: Mesh.Supervisor]
    Supervisor.start_link(children ++ monitors(), opts)
  end

  defp peers do
    Application.get_env(:mesh, :peers, [])
  end

  defp monitors do
    Enum.map(peers(), fn peer ->
      Supervisor.child_spec({Mesh.Monitor, peer}, id: {Mesh.Monitor, peer})
    end)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MeshWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
