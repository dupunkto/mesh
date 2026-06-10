const PEERS = [
  "nov.mesh.dupunkto.org",
  "dec.mesh.dupunkto.org",
  "jun.mesh.dupunkto.org",
  "feb.mesh.dupunkto.org"
];

const POLL_INTERVAL_MS = 5_000;
const RELAY_STALE_MS = 4 * POLL_INTERVAL_MS;
const CLOCK_SKEW_MS = 2 * 60_000;

const EDGE_COLORS = { up: "#2a7", down: "#c33", unknown: "#888" };

async function probe(peer) {
  try {
    const res = await fetch(`https://${peer}/state`);
    if (!res.ok) return { peer, reachable: false };
    return { peer, reachable: true, data: await res.json() };
  } catch {
    return { peer, reachable: false };
  }
}

function calculateClockSkews(results) {
  return new Map(results.map((r) => {
    if (!r.reachable || !r.data?.relay) return [r.peer, 0];
    let max = 0;
    for (const entry of Object.values(r.data.relay)) {
      const received = new Date(entry.received_at).getTime();
      for (const info of Object.values(entry.peers ?? {})) {
        const skew = new Date(info.last_seen).getTime() - received;
        if (skew > max) max = skew;
      }
    }
    return [r.peer, Math.min(max, CLOCK_SKEW_MS)];
  }));
}

function resolveRelayStatus(results, skews, target) {
  let best = null;
  let bestAdjusted = -Infinity;

  for (const r of results) {
    if (!r.reachable || r.peer === target) continue;
    const entry = r.data?.relay?.[target];
    if (!entry) continue;

    const adjusted = new Date(entry.received_at).getTime() + (skews.get(r.peer) ?? 0);
    if (adjusted > bestAdjusted) {
      best = entry;
      bestAdjusted = adjusted;
    }
  }

  if (!best) return null;
  return Date.now() - bestAdjusted > RELAY_STALE_MS ? "stale" : "fresh";
}

function renderTable(results, skews) {
  const byPeer = new Map(results.map((r) => [r.peer, r]));

  const rows = PEERS.map((target) => {
    const self = byPeer.get(target);
    const observers = results.filter((r) => r.peer !== target && r.reachable && r.data.peers?.[target]);
    const downFrom = observers.filter((o) => o.data.peers[target].status === "down");
    const upCount = observers.length - downFrom.length;

    const reachable = self.reachable;
    let status = reachable ? "up" : "down";
    let detail = reachable ? "reachable from browser" : "unreachable from browser";

    if (observers.length > 0) {
      detail += reachable
        ? ` and ${upCount}/${observers.length} peers`
        : `, up for ${upCount}/${observers.length} peers`;
      if (reachable ? downFrom.length > 0 : upCount > 0) status = "partial";
    } else {
      detail += " (no peers)";
    }

    if (!reachable) {
      const relay = resolveRelayStatus(results, skews, target);
      if (relay === "fresh") detail += ", outbound fine";
      else if (relay === "stale") detail += ", outbound stale";
    }

    const title = downFrom.length > 0
      ? `unreachable from: ${downFrom.map((o) => o.peer).join(", ")}`
      : "";

    return { target, status, detail, title };
  });

  document.querySelector("#nodes tbody").replaceChildren(...rows.map((row) => {
    const tr = document.createElement("tr");
    tr.className = row.status;
    tr.append(buildCell(row.target), buildCell(row.detail, row.title), buildCell(row.status));
    return tr;
  }));

  document.querySelector("#meta").textContent =
    `last updated at ${new Date().toLocaleTimeString()}`;
}

function buildCell(text, title = null) {
  const td = document.createElement("td");
  td.textContent = text;
  if (title) td.title = title;
  return td;
}

function renderGraph(results, skews) {
  const byPeer = new Map(results.map((r) => [r.peer, r]));

  const nodes = PEERS.map((peer) => {
    const observers = PEERS.filter((from) =>
      from !== peer && byPeer.get(from)?.reachable && byPeer.get(from)?.data?.peers?.[peer]
    );
    const allDown = observers.length > 0 &&
      observers.every((from) => normalizeStatus(byPeer.get(from).data.peers[peer].status) === "down");

    return { data: { id: peer, label: peer, bg: allDown ? "#c33" : "#fff", fg: allDown ? "#fff" : "#000" } };
  });

  const edges = PEERS.flatMap((from) =>
    PEERS
      .filter((to) => from !== to)
      .map((to) => {
        const { color, lineStyle } = edgeStyle(from, to, byPeer, skews);
        return { data: { id: `${from}->${to}`, source: from, target: to, color, lineStyle } };
      })
  );

  const cy = cytoscape({
    container: document.querySelector("#graph"),
    elements: { nodes, edges },
    layout: { name: "circle", fit: true, padding: 10 },
    userZoomingEnabled: false,
    userPanningEnabled: false,
    style: [
      {
        selector: "node",
        style: {
          label: "data(label)",
          "font-family": getComputedStyle(document.body).fontFamily,
          "text-valign": "center",
          "background-color": "data(bg)",
          "border-width": 1,
          "border-color": "#000",
          color: "data(fg)",
          shape: "rectangle",
          width: 200,
          height: 30
        }
      },
      {
        selector: "edge",
        style: {
          "line-color": "data(color)",
          "line-style": "data(lineStyle)",
          "target-arrow-color": "data(color)",
          "target-arrow-shape": "triangle",
          "curve-style": "bezier",
          "arrow-scale": 1.5,
          width: 3
        }
      }
    ]
  });
  cy.resize();
  cy.fit(undefined, 10);
}

function normalizeStatus(status) {
  return status === "up" || status === "down" ? status : "unknown";
}

function edgeStyle(from, to, byPeer, skews) {
  const fromResult = byPeer.get(from);

  if (fromResult?.reachable) {
    const status = normalizeStatus(fromResult.data.peers?.[to]?.status);
    return { color: EDGE_COLORS[status], lineStyle: "solid" };
  }

  const toResult = byPeer.get(to);
  const relay = toResult?.reachable ? toResult.data?.relay?.[from] : null;
  if (!relay) return { color: EDGE_COLORS.unknown, lineStyle: "solid" };

  const age = Date.now() - new Date(relay.received_at).getTime() - (skews.get(to) ?? 0);
  if (age > RELAY_STALE_MS) return { color: EDGE_COLORS.unknown, lineStyle: "dashed" };

  const status = relay.peers?.[to]?.status === "up" ? "up" : "unknown";
  return { color: EDGE_COLORS[status], lineStyle: "dashed" };
}

Promise.all(PEERS.map(probe)).then((results) => {
  const skews = calculateClockSkews(results);
  renderTable(results, skews);
  renderGraph(results, skews);
});
