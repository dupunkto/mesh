defmodule MeshWeb.APIController do
  @moduledoc false
  use MeshWeb, :controller

  alias Mesh.Store

  def root(conn, _params) do
    redirect(conn, external: Mesh.aggregator())
  end

  def ping(conn, _params) do
    json(conn, %{pong: true})
  end

  def state(conn, _params) do
    json(conn, %{node: Mesh.me(), peers: Store.all(), relay: Store.all_relays()})
  end

  def relay(conn, %{"node" => from, "peers" => peers}) do
    expected = Application.fetch_env!(:mesh, :relay_secret)
    known = Application.get_env(:mesh, :peers, [])

    case get_req_header(conn, "authorization") do
      [^expected] ->
        if from in known do
          Store.put_relay(from, peers)
          json(conn, %{ok: true})
        else
          conn |> put_status(:forbidden) |> json(%{error: "unknown node"}) |> halt()
        end

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "unauthorized"}) |> halt()
    end
  end
end
