const PEERS = [
  "nov.mesh.dupunkto.org",
  "dec.mesh.dupunkto.org",
  "jun.mesh.dupunkto.org",
  "feb.mesh.dupunkto.org"
];

const POLL_INTERVAL_MS = 5_000;
const RELAY_STALE_MS = 4 * POLL_INTERVAL_MS;

async function probe(peer) {
  try {
    const res = await fetch(`https://${peer}/state`);
    if (!res.ok) return { peer, reachable: false };
    return { peer, reachable: true, data: await res.json() };
  } catch {
    return { peer, reachable: false };
  }
}

function relayStatus(results, target) {
  let best = null;
  for (const r of results) {
    if (!r.reachable || r.peer === target) continue;
    const entry = r.data?.relay?.[target];
    if (entry && (!best || entry.received_at > best.received_at)) best = entry;
  }
  if (!best) return null;
  return Date.now() - new Date(best.received_at).getTime() > RELAY_STALE_MS ? "stale" : "fresh";
}

function consensus(results) {
  const byPeer = new Map(results.map((r) => [r.peer, r]));

  return PEERS.map((target) => {
    const self = byPeer.get(target);
    const observers = results.filter((r) => r.peer !== target && r.reachable && r.data.peers?.[target]);
    const downFrom = observers.filter((o) => o.data.peers[target].status === "down");

    if (!self.reachable) {
      let status = "down";
      let detail = "unreachable from browser";
      let title = "";

      if (observers.length > 0) {
        detail += `, up for ${observers.length - downFrom.length}/${observers.length} peers`;
        status = observers.length === downFrom.length ? "down" : "partial";
      } else {
        detail += " (no peers)";
      }

      if (downFrom.length > 0) {
        title = `unreachable from: ${downFrom.map((o) => o.peer).join(", ")}`;
      }

      const relay = relayStatus(results, target);
      if (relay === "fresh") detail += ", outbound fine";
      else if (relay === "stale") detail += ", outbound down";

      return { target, status, detail, title };
    } else {
      let status = "up";
      let detail = "reachable from browser";
      let title = "";

      if (observers.length > 0) {
        detail += ` and ${observers.length - downFrom.length}/${observers.length} peers`;
        if (downFrom.length > 0) status = "partial";
      } else {
        detail += " (no peers)";
      }

      if (downFrom.length > 0) {
        title = `unreachable from: ${downFrom.map((o) => o.peer).join(", ")}`;
      }

      return { target, status, detail, title };
    }
  });
}

function render(rows) {
  const table = document.querySelector("#nodes tbody");

  table.replaceChildren(
    ...rows.map((row) => {
      const tr = document.createElement("tr");
      tr.className = row.status;
      tr.innerHTML = `<td>${row.target}</td><td${row.title ? ` title="${row.title}"` : ""}>${row.detail}</td><td>${row.status}</td>`;
      return tr;
    })
  );

  document.querySelector("#meta").textContent = `last updated at ${new Date().toLocaleTimeString()}`;
}

function renderGraph(results) {
  const byPeer = new Map(results.map((r) => [r.peer, r]));
  const normalize = (v) => (v === "up" || v === "down" ? v : "unknown");
  const colors = { up: "#2a7", down: "#c33", unknown: "#888" };

  const nodes = PEERS.map((peer) => {
    const observers = PEERS.filter((from) => from !== peer && byPeer.get(from)?.reachable && byPeer.get(from)?.data?.peers?.[peer]);
    const hasDown = observers.length > 0 && observers.every((from) => normalize(byPeer.get(from).data.peers[peer].status) === "down");
    return { data: { id: peer, label: peer, bg: hasDown ? "#c33" : "#fff", fg: hasDown ? "#fff" : "#000" } };
  });

  const edges = [];
  for (const from of PEERS) {
    for (const to of PEERS) {
      if (from === to) continue;
      let color, line_style;

      if (byPeer.get(from)?.reachable) {
        color = colors[normalize(byPeer.get(from).data.peers?.[to]?.status)];
        line_style = "solid";
      } else {
        const relay = byPeer.get(to)?.reachable && byPeer.get(to)?.data?.relay?.[from];
        if (!relay) {
          color = colors.unknown;
          line_style = "solid";
        } else {
          const age = Date.now() - new Date(relay.received_at).getTime();
          if (age > RELAY_STALE_MS) {
            color = colors.down;
            line_style = "solid";
          } else {
            color = relay.peers?.[to]?.status === "up" ? colors.up : colors.unknown;
            line_style = "dashed";
          }
        }
      }

      edges.push({
        data: { id: `${from}->${to}`, source: from, target: to, color, line_style }
      });
    }
  }

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
          "line-style": "data(line_style)",
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

Promise.all(PEERS.map(probe)).then((results) => {
  render(consensus(results));
  renderGraph(results);
});
