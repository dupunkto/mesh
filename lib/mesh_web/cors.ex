defmodule MeshWeb.CORS do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = put_resp_header(conn, "access-control-allow-origin", "*")

    if conn.method == "OPTIONS" do
      conn
      |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
      |> put_resp_header("access-control-allow-headers", "*")
      |> send_resp(204, "")
      |> halt()
    else
      conn
    end
  end
end
