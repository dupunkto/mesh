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
    json(conn, %{node: Mesh.me(), peers: Store.peers(), relay: Store.relays()})
  end

  def relay(conn, %{"node" => from, "peers" => peers}) do
    secret = Application.get_env(:mesh, :relay_secret)
    known_peers = Application.get_env(:mesh, :peers, [])

    case {secret, get_req_header(conn, "authorization")} do
      {nil, _} ->
        conn |> put_status(501) |> json(%{error: "relay is disabled"}) |> halt()

      {secret, [secret]} ->
        if from in known_peers do
          Store.put_relay(from, peers)
          json(conn, %{ok: true})
        else
          conn |> put_status(401) |> json(%{error: "unknown node"}) |> halt()
        end

      _ ->
        conn |> put_status(403) |> json(%{error: "unauthorized"}) |> halt()
    end
  end
end
