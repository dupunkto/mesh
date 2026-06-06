defmodule MeshWeb.APIController do
  @moduledoc false
  use MeshWeb, :controller

  alias Mesh.Store

  def ping(conn, _params) do
    json(conn, %{pong: true})
  end

  def state(conn, _params) do
    json(conn, %{node: Mesh.me(), peers: Store.all()})
  end
end