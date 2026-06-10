# Mesh

<!-- DOCS HERE -->

Mesh is the distributed uptime monitor used by the {du}punkto network.

## Topology

Every node runs an identical Mesh instance, which polls its peers on a fixed interval. There is no central coordinator or shared state, each node builds its own view of the cluster. An aggregator collects states, computes consensus, and renders them into an uptime graph.

The implemented aggregator running at [mesh.dupunkto.org](https://mesh.dupunkto.org) is static HTML served by GitHub Pages, that uses the [Fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch) to pull states from all nodes in the cluster.

> This means the status page is dependent on the network condition of the user, but it also prevents a single server, and thus a single point of failure.

## Endpoints

- `GET /`: redirects to the `AGGREGATOR_URL`.

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
    },
    "relay": {
      "dec.mesh.dupunkto.org": {
        "received_at": "2026-06-06T13:01:28Z",
        "peers": {
          "nov.mesh.dupunkto.org": {
            "status": "up",
            "since": "2026-06-06T12:42:00Z",
            "last_seen": "2026-06-06T13:01:28Z",
            "consecutive_failures": 0
          }
        }
      }
    }
  }
  ```

  The `relay` field contains the most recently received state from each peer. This allows the aggregator to reconstruct a peer's outbound connections even if it cannot reach that peer directly.

- `POST /relay`: accepts a peer's state and stores it. Requires an `Authorization` header matching the shared `RELAY_SECRET`. Body:

  ```json
  {
    "node": "dec.mesh.dupunkto.org",
    "peers": {
      "nov.mesh.dupunkto.org": {
        "status": "up",
        "since": "2026-06-06T12:42:00Z",
        "last_seen": "2026-06-06T13:01:28Z",
        "consecutive_failures": 0
      }
    }
  }
  ```

## Deployment

Configure the following environment variables:

- `PEERS`: comma-separated peer hostnames. Required, the app will not boot without.

- `WEBHOOK_URL`: optional Discord or Slack incoming webhook for notifications. See more in the following section.

- `NODE`: a unique identifier for the node. Used in webhook messages and returned in the `node` field of `/state`. Defaults to the system hostname if not given.

- `AGGREGATOR_URL`: a URL to the mesh aggregator. This is only used to redirect from `/` to the aggregator page. Defaults to `https://mesh.dupunkto.org` if not given.

- `RELAY_SECRET`: shared secret used to authenticate `POST /relay` requests between nodes. All nodes in the cluster must use the same value. Required, the app will not boot without.

A prebuilt docker image is available at [ghcr.io/dupunkto/mesh](https://github.com/dupunkto/mesh/pkgs/container/mesh).

## Webhook integration

Optional Discord or Slack webhooks can be configured using the `WEBHOOK_URL` environment variable. The payload looks like:

```json
{"content": "🔴 `dec.mesh.dupunkto.org` is unreachable from `nov.mesh.dupunkto.org`"}
```

On recovery, including how long the peer was unreachable:

```json
{"content": "🟢 `dec.mesh.dupunkto.org` is reachable again from `nov.mesh.dupunkto.org` (was unreachable for 4m 32s)"}
```

If a peer remains unreachable, a follow-up is sent every 30 minutes:

```json
{"content": "🟠 `dec.mesh.dupunkto.org` is still unreachable from `nov.mesh.dupunkto.org` (35m 12s)"}
```

This webhook will be called upon every status transition, except the initial change from `:unknown` to `:up` on application boot, to reduce log spam.

> Whenever a node goes down, multiple nodes will report a status transition, resulting in
> multiple messages. This is by design, because it can help pinpoint the issue.
