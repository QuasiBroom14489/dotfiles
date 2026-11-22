// A tiny 3D force-directed graph renderer.
//
// Self-contained on purpose: the other widgets pull in no npm packages, and a
// dependency here would mean trusting browserify to bundle it into a widget
// that has to survive Übersicht's own reload cycle. The whole thing is a
// spring/repulsion integrator plus a perspective projection — far less code
// than wiring up three.js would have been.
//
// Lives under lib/ because Übersicht's scanner skips that path, so this is not
// picked up as a (render-less, broken) widget.

// ── layout ──────────────────────────────────────────────────────────────────

const REPULSION = 3600;   // node-node push
const SPRING = 0.0135;    // edge pull toward REST_LEN
const REST_LEN = 86;
const CENTERING = 0.0034; // keeps the cloud from drifting off-canvas
const DAMPING = 0.86;

function step(nodes, links) {
  for (const n of nodes) {
    n.fx = 0;
    n.fy = 0;
    n.fz = 0;
  }

  // Repulsion. O(n²) is irrelevant at nine nodes and keeps this readable.
  for (let i = 0; i < nodes.length; i++) {
    for (let j = i + 1; j < nodes.length; j++) {
      const a = nodes[i];
      const b = nodes[j];
      let dx = a.x - b.x;
      let dy = a.y - b.y;
      let dz = a.z - b.z;
      let d2 = dx * dx + dy * dy + dz * dz;
      // Floor the distance so two coincident nodes don't produce infinite force.
      if (d2 < 1) d2 = 1;
      const d = Math.sqrt(d2);
      const f = REPULSION / d2;
      const ux = dx / d;
      const uy = dy / d;
      const uz = dz / d;
      a.fx += ux * f;
      a.fy += uy * f;
      a.fz += uz * f;
      b.fx -= ux * f;
      b.fy -= uy * f;
      b.fz -= uz * f;
    }
  }

  for (const l of links) {
    const a = l.a;
    const b = l.b;
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const dz = b.z - a.z;
    const d = Math.sqrt(dx * dx + dy * dy + dz * dz) || 1;
    const f = (d - REST_LEN) * SPRING;
    const ux = dx / d;
    const uy = dy / d;
    const uz = dz / d;
    a.fx += ux * f;
    a.fy += uy * f;
    a.fz += uz * f;
    b.fx -= ux * f;
    b.fy -= uy * f;
    b.fz -= uz * f;
  }

  for (const n of nodes) {
    if (n.pinned) {
      n.x = 0;
      n.y = 0;
      n.z = 0;
      n.vx = n.vy = n.vz = 0;
      continue;
    }
    n.fx -= n.x * CENTERING;
    n.fy -= n.y * CENTERING;
    n.fz -= n.z * CENTERING;

    n.vx = (n.vx + n.fx) * DAMPING;
    n.vy = (n.vy + n.fy) * DAMPING;
    n.vz = (n.vz + n.fz) * DAMPING;
    n.x += n.vx;
    n.y += n.vy;
    n.z += n.vz;
  }
}

// ── renderer ────────────────────────────────────────────────────────────────

const FOCAL = 520; // perspective strength; larger = flatter
// Vertical room reserved for the label that hangs under each node.
const LABEL_ROOM = 18;
// `fit` scales up as well as down, so a roomier card gets a bigger graph
// rather than more empty margin. It is a single uniform factor applied to
// positions, radii and label sizes alike, so filling the card is a zoom — the
// layout's proportions never distort. Capped only to stop a very large card
// inflating eight nodes into something absurd.
const MAX_FIT = 2.8;

/** Evenly distributed point i of n on a unit sphere. */
function sphere(i, n) {
  const y = 1 - (i / Math.max(1, n - 1)) * 2;
  const r = Math.sqrt(Math.max(0, 1 - y * y));
  const theta = i * 2.399963; // golden angle
  return [Math.cos(theta) * r, y, Math.sin(theta) * r];
}

export function createGraph(canvas, opts) {
  const { spec, links: linkSpec, palette, accentFor } = opts;

  const nodes = spec.map((s, i) => ({
    id: s.id,
    label: s.label,
    group: s.group,
    r: s.r,
    pinned: !!s.pinned,
    // Fibonacci sphere seed. A ring seed left pairs of nodes nearly
    // coincident in projection, which read as a rendering bug rather than
    // depth; distributing over a sphere settles into a genuine volume.
    x: s.pinned ? 0 : sphere(i, spec.length)[0] * 88,
    y: s.pinned ? 0 : sphere(i, spec.length)[1] * 88,
    z: s.pinned ? 0 : sphere(i, spec.length)[2] * 88,
    vx: 0,
    vy: 0,
    vz: 0,
    energy: 0,
    // Per-node phase so the ambient bob never looks synchronised.
    phase: (i * 2.399) % (Math.PI * 2),
  }));

  const byId = new Map(nodes.map((n) => [n.id, n]));
  const links = linkSpec
    .map(([a, b]) => ({ a: byId.get(a), b: byId.get(b), flow: 0 }))
    .filter((l) => l.a && l.b);

  // Settle before the first paint so the graph never visibly flies apart.
  for (let i = 0; i < 320; i++) step(nodes, links);

  const ctx = canvas.getContext('2d');
  let raf = 0;
  let t = 0;
  let yaw = 0;
  let state = 'idle';
  let connected = false;
  let w = 0;
  let h = 0;
  // Smoothed scale that keeps the whole cloud inside the canvas. Recomputed
  // every frame from the actual projected extent, so rotation bringing a node
  // toward the camera can never push it out of frame — and it adapts to any
  // canvas size without hand-tuned constants.
  let fit = 1;

  function resize() {
    const dpr = window.devicePixelRatio || 1;
    w = canvas.clientWidth;
    h = canvas.clientHeight;
    canvas.width = Math.max(1, Math.round(w * dpr));
    canvas.height = Math.max(1, Math.round(h * dpr));
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  resize();
  const ro = typeof ResizeObserver !== 'undefined' ? new ResizeObserver(resize) : null;
  if (ro) ro.observe(canvas);

  function project(n, bob) {
    // Yaw about Y, then a fixed tilt about X so the cloud reads as a volume
    // rather than a spinning disc.
    const cy = Math.cos(yaw);
    const sy = Math.sin(yaw);
    const x1 = n.x * cy - n.z * sy;
    const z1 = n.x * sy + n.z * cy;

    const TILT = 0.32;
    const ct = Math.cos(TILT);
    const st = Math.sin(TILT);
    const y2 = (n.y + bob) * ct - z1 * st;
    const z2 = (n.y + bob) * st + z1 * ct;

    const scale = FOCAL / (FOCAL + z2);
    // Labels hang below a node, so the usable half-height is short of centre.
    return {
      ox: x1 * scale,
      oy: y2 * scale,
      sx: w / 2 + x1 * scale * fit,
      sy: h / 2 - LABEL_ROOM / 2 + y2 * scale * fit,
      scale,
      depth: z2,
    };
  }

  function frame() {
    t += 1;

    // Thinking spins faster and agitates the layout; idle just drifts.
    const spin = state === 'thinking' ? 0.0075 : state === 'idle' ? 0.0022 : 0.004;
    yaw += spin;
    if (t % 2 === 0) step(nodes, links);

    ctx.clearRect(0, 0, w, h);
    if (!w || !h) {
      raf = requestAnimationFrame(frame);
      return;
    }

    const accent = accentFor(connected ? state : 'offline');

    // Ambient vertical bob, per node, independent of the physics.
    const bobs = nodes.map((n) => (n.pinned ? 0 : Math.sin(t / 62 + n.phase) * 5.5));
    let proj = nodes.map((n, i) => project(n, bobs[i]));

    // Fit pass: measure the unscaled extent, then ease `fit` toward the value
    // that keeps it inside. Easing rather than snapping stops the graph from
    // pumping as nodes rotate toward and away from the camera.
    // Solve for `fit` directly rather than dividing by an extent that mixes
    // scaled and unscaled terms. Offsets and radii scale with `fit`; the label
    // box does not. Writing the constraint out and solving removes both the
    // circular dependency on the current `fit` and the over-conservatism that
    // was leaving the graph at ~64% of the canvas.
    //
    //   |offset|*fit + radius*fit + labelBox  <=  halfExtent - EDGE
    //
    // Vertically the centre is already shifted up by LABEL_ROOM/2, so the top
    // and bottom constraints reduce to the same bound.
    const EDGE = 6;
    const budgetY = h / 2 - LABEL_ROOM / 2 - EDGE;
    let want = MAX_FIT;
    for (let i = 0; i < proj.length; i++) {
      const n = nodes[i];
      const rr = n.r * proj[i].scale;
      // Labels are centred under their node, so horizontally a node reaches
      // whichever is wider — its circle or its text.
      const halfLabel = n.label.length * 3.2;
      const reachX = Math.abs(proj[i].ox) + Math.max(rr, halfLabel);
      const reachY = Math.abs(proj[i].oy) + rr;
      want = Math.min(
        want,
        (w / 2 - EDGE) / Math.max(1, reachX),
        budgetY / Math.max(1, reachY),
      );
    }
    fit += (want - fit) * 0.06;
    proj = nodes.map((n, i) => project(n, bobs[i]));

    // Edges first, so nodes always sit on top of them.
    for (const l of links) {
      const pa = proj[nodes.indexOf(l.a)];
      const pb = proj[nodes.indexOf(l.b)];
      const near = Math.max(pa.scale, pb.scale);
      ctx.beginPath();
      ctx.moveTo(pa.sx, pa.sy);
      ctx.lineTo(pb.sx, pb.sy);
      ctx.strokeStyle = palette.gutter;
      ctx.globalAlpha = Math.min(0.5, 0.13 + near * 0.2) + l.flow * 0.45;
      ctx.lineWidth = 0.9 * near + l.flow * 1.5;
      ctx.stroke();

      if (l.flow > 0.03) {
        const p = (t % 54) / 54;
        ctx.beginPath();
        ctx.arc(pa.sx + (pb.sx - pa.sx) * p, pa.sy + (pb.sy - pa.sy) * p, 2 * near, 0, Math.PI * 2);
        ctx.fillStyle = accent;
        ctx.globalAlpha = l.flow;
        ctx.fill();
      }
      ctx.globalAlpha = 1;
      l.flow *= 0.975;
    }

    // Painter's algorithm: far nodes first so near ones overlap them.
    const order = nodes.map((_, i) => i).sort((i, j) => proj[j].depth - proj[i].depth);

    for (const i of order) {
      const n = nodes[i];
      const p = proj[i];
      const base = n.pinned ? accent : palette.group[n.group];
      const breathe = 0.5 + 0.5 * Math.sin(t / (state === 'thinking' ? 15 : 52));
      const live = n.pinned && connected ? breathe * (state === 'thinking' ? 0.7 : 0.28) : 0;
      const e = Math.max(n.energy, live);

      // Depth drives size and opacity — the only cues that sell 3D here.
      const r = n.r * p.scale * fit * (1 + e * 0.5);
      const depthAlpha = Math.max(0.25, Math.min(1, p.scale * 0.95));

      if (e > 0.03) {
        ctx.shadowBlur = 22 * e * p.scale;
        ctx.shadowColor = base;
      }
      ctx.beginPath();
      ctx.arc(p.sx, p.sy, Math.max(1, r), 0, Math.PI * 2);
      ctx.globalAlpha = depthAlpha;
      ctx.fillStyle = e > 0.03 ? base : palette.bgHighlight;
      ctx.fill();
      ctx.shadowBlur = 0;

      ctx.beginPath();
      ctx.arc(p.sx, p.sy, Math.max(1, r), 0, Math.PI * 2);
      ctx.strokeStyle = base;
      ctx.globalAlpha = depthAlpha * (0.4 + e * 0.6);
      ctx.lineWidth = 1.1;
      ctx.stroke();

      // Every node keeps its label; far ones just fade. Hiding them outright
      // made nodes on the back of the rotation look like a rendering fault.
      if (p.scale > 0.84) {
        // Fade the label with depth so the far side reads as distance.
        const near = Math.max(0, Math.min(1, (p.scale - 0.84) / 0.28));
        ctx.globalAlpha = depthAlpha * (n.pinned || e > 0.25 ? 0.95 : 0.22 + near * 0.4);
        ctx.font = `${(n.pinned ? 9.5 : 8.5) * Math.min(1.15, p.scale) * Math.min(1.25, fit)}px ${palette.font}`;
        ctx.textAlign = 'center';
        ctx.fillStyle = e > 0.25 || n.pinned ? palette.fg : palette.comment;
        ctx.fillText(n.label, p.sx, p.sy + r + 10);
      }
      ctx.globalAlpha = 1;

      n.energy *= 0.972;
    }

    raf = requestAnimationFrame(frame);
  }

  raf = requestAnimationFrame(frame);

  return {
    setState(next, isConnected) {
      state = next;
      connected = isConnected;
    },
    /** Light a node and the edges feeding it. */
    pulse(nodeId) {
      const n = byId.get(nodeId);
      if (n) n.energy = 1;
      for (const l of links) {
        if (l.a.id === nodeId || l.b.id === nodeId) l.flow = 1;
      }
    },
    destroy() {
      cancelAnimationFrame(raf);
      if (ro) ro.disconnect();
    },
  };
}
