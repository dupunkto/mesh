defmodule Mesh do
  @moduledoc """
  Mesh is the distributed uptime monitor used by the {du}punkto network.

  ## Topology
  
  Every node runs an idential Mesh instance, which polls its peers on a fixed interval. There is no central coordinator or shared state, each node builds its own view of the cluster. An aggregator collects states, computes consensus, and renders them into an uptime graph.

  The implemented aggregator running at [mesh.dupunkto.org](https://mesh.dupunkto.org) is static HTML served by GitHub Pages, that uses the [Fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch) to pull states from all nodes in the cluster.

  > This means the status page is dependent on the network condition of the user, but it also prevents a single server, and thus a single point of failure.

  ## Endpoints

    - `GET /ping`: liveness probe, returns:

      ```json
      {"pong": true}
      ```

    - `GET /state`: view of the cluster, returns:

      ```json
      {
        "node": "nov.mesh.dupunkto.org",
        "peers": {
          "dec.mesh.dupunkto.org": {
            "status": "up",
            "since": "2026-06-06T12:42:00Z",
            "last_seen": "2026-06-06T13:01:30Z",
            "consecutive_failures": 0
          }
        }
      }
      ```

  ## Deployment

  Configure the following environment variables:

    - `PEERS`: comma-separated peer hostnames. If not given, nothing will be monitored.

    - `WEBHOOK_URL`: optional Discord or Slack incoming webhook for
      notifications.
    - `NODE`: a unique identifier for the node. Used in webhook messages and returned in the `node` field of `/state`. Defaults to the system hostname if not given.

    - `MESH`: a URL to the mesh aggregator. This is only used to redirect from `/` to the aggregator page. Defaults to
      `https://mesh.dupunkto.org` if not given.

  A prebuilt docker image is available at [ghcr.io/dupunkto/mesh](https://github.com/dupunkto/mesh/pkgs/container/mesh).

  ## Webhook integration

  Optional Discord or Slack webhooks can be configured using the `WEBHOOK_URL` environment variable. The payload looks like:

  ```json
  {"content": "🟥 `dec.mesh.dupunkto.org` cannot be reached by `nov.mesh.dupunkto.org`"}
  ```

  Or, on recovery:

  ```json
  {"content": "🟩 `dec.mesh.dupunkto.org` can be reached by `nov.mesh.dupunkto.org`"}
  ```

  This webhook will be called upon every status transition, except the initial change from `:unknown` to `:up` on application boot, to reduce log spam.

  > Whenever a node goes down, multiple nodes will report a status transition, resulting in
  > multiple messages. This is by design, because it can help pinpoint the issue.
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
