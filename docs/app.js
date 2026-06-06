const PEERS = [
  "nov.mesh.dupunkto.org",
  "dec.mesh.dupunkto.org"
];

async function probe(peer) {
  try {
    const res = await fetch(`https://${peer}/state`);
    if (!res.ok) return { peer, reachable: false };
    return { peer, reachable: true, data: await res.json() };
  } catch {
    return { peer, reachable: false };
  }
}

function consensus(results) {
  const byPeer = new Map(results.map((r) => [r.peer, r]));

  return PEERS.map((target) => {
    const self = byPeer.get(target);
    const observers = results.filter((r) => r.peer != target && r.reachable);
    const downFrom = observers.filter((o) => o.data.peers?.[target]?.status == "down");

    if (!self.reachable) {
      let status = "down";
      let detail = "unreachable from browser";
      let title = "";
      
      if (observers.length > 0) {
        detail += ` and ${downFrom.length}/${observers.length} peers`;
        status = observers.length == downFrom.length ? "down" : "partial";
      }
      else {
        detail += " (no peers)";
      }

      if(downFrom.length > 0) {
        title = `unreachable from: ${downFrom.map((o) => o.peer).join(", ")}`;
      }

      return { target, status, detail, title };
    }
    else {
      let status = "up";
      let detail = "reachable from browser";
      let title = "";

      if (observers.length > 0) {
        detail += ` and ${observers.length - downFrom.length}/${observers.length} peers`;
        if(downFrom.length > 0) status = "partial";
      } else {
        detail += " (no peer observations available)";
      }

      if(downFrom.length > 0) {
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
      tr.innerHTML = `<td>${row.target}</td><td title="${row.title}">${row.detail}</td><td>${row.status}</td>`;
      return tr;
    }),
  );

  document.querySelector("#meta").textContent =
    `last updated: ${new Date().toLocaleTimeString()}`;
}

function buildGraph(results) {
  const byPeer = new Map(results.map((r) => [r.peer, r]));
  const id = (peer) => peer.replace(/[^a-zA-Z0-9]/g, "_");

  const lines = ["flowchart LR"];

  for (const peer of PEERS)
    lines.push(`  ${id(peer)}["${peer}"]`);

  const statuses = [];
  for (const from of PEERS) {
    for (const to of PEERS) {
      if (from == to) continue;
      const view = byPeer.get(from)?.data?.peers?.[to]?.status;
      const status = view == "up" || view == "down" ? view : "unknown";
      lines.push(`  ${id(from)} -->|${status}| ${id(to)}`);
      statuses.push(status);
    }
  }

  const colors = { up: "#2a7", down: "#c33", unknown: "#888" };
  statuses.forEach((s, i) => {
    lines.push(`  linkStyle ${i} stroke:${colors[s]},stroke-width:3px,color:${colors[s]}`);
  });

  return lines.join("\n");
}

async function renderGraph(results) {
  mermaid.initialize({ startOnLoad: false, theme: "neutral" });
  const { svg } = await mermaid.render("graph-svg", buildGraph(results));
  document.querySelector("#graph").innerHTML = svg;
}

Promise.all(PEERS.map(probe)).then((results) => {
  render(consensus(results));
  renderGraph(results);
});
