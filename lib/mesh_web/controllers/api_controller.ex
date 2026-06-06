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
    json(conn, %{node: Mesh.me(), peers: Store.all()})
  end
end