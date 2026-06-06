defmodule Mesh do
  @moduledoc """
  Distributed uptime monitoring.
  """

  @doc false
  @spec mesh() :: String.t()
  def mesh do
    Application.get_env(:mesh, :mesh_url) || "https://mesh.dupunkto.org"
  end

  @doc false
  @spec me() :: String.t()
  def me do
    Application.get_env(:mesh, :node) || hostname()
  end

  defp hostname do
    {:ok, hostname} = :inet.gethostname()
    List.to_string(hostname)
  end
end
