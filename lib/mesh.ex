defmodule Mesh do
  @moduledoc """
  Distributed uptime monitoring.
  """

  @doc """
  Returns this node's identifier, used as the sender in notifications and as
  the `node` field in `/state` responses. Falls back to the system hostname
  if `:node` is unset.
  """
  @spec me() :: String.t()
  def me do
    Application.get_env(:mesh, :node) || hostname()
  end

  defp hostname do
    {:ok, hostname} = :inet.gethostname()
    List.to_string(hostname)
  end
end
