// Vesper — an ambient 3D view of what the assistant is doing.
//
// The HUD's graph only exists while the overlay is open. This is the same idea
// left permanently on the desktop: a slowly rotating cloud of Vesper's
// capabilities that lights up when a tool actually fires.
//
// It is a genuine readout, not decoration. Nodes are the real tool names, and a
// `tool.call` event lights the matching node — so the desktop shows the same
// truth the HUD does, because both read the same event stream.

import { tn, card, FONT } from "./lib/tokyonight.js";
import { createGraph } from "./lib/vesper-graph3d.js";

// No shell command: this widget is driven entirely by a WebSocket to the
// daemon. Polling would force a re-render every tick and remount the canvas,
// throwing away the animation. `false` means Übersicht renders once and leaves
// us alone, which is exactly what a continuously animating canvas wants.
export const refreshFrequency = false;

const HOST = "127.0.0.1";
const PORT = 4873;

const SPEC = [
  { id: "core", label: "VESPER", group: "core", r: 11, pinned: true },
  { id: "vault.search", label: "search", group: "vault", r: 6.5 },
  { id: "vault.read", label: "read", group: "vault", r: 6.5 },
  { id: "vault.write", label: "write", group: "vault", r: 6 },
  { id: "schedule", label: "schedule", group: "time", r: 6.5 },
  { id: "reminders", label: "reminders", group: "action", r: 6.5 },
  { id: "organize", label: "organize", group: "action", r: 7.5 },
  { id: "web", label: "web", group: "world", r: 6 },
  { id: "screen", label: "screen", group: "world", r: 6 },
  { id: "self", label: "self", group: "core", r: 7 },
];

const LINKS = [
  ["core", "vault.search"], ["core", "vault.read"], ["core", "vault.write"],
  ["core", "schedule"], ["core", "reminders"], ["core", "organize"], ["core", "web"],
  ["vault.search", "vault.read"], ["vault.read", "vault.write"],
  ["schedule", "reminders"], ["organize", "vault.write"], ["web", "vault.read"],
  ["core", "screen"], ["core", "self"], ["self", "organize"], ["screen", "web"],
];

// Tool name as emitted by the daemon → node id. Mirrors the HUD's map;
// an unknown tool lands on the hub rather than being dropped silently.
const TOOL_NODE = {
  mcp__vesper__search: "vault.search",
  mcp__vesper__read: "vault.read",
  mcp__vesper__write: "vault.write",
  mcp__vesper__schedule: "schedule",
  mcp__vesper__reminders_list: "reminders",
  mcp__vesper__reminders_create: "reminders",
  mcp__vesper__run: "organize",
  mcp__vesper__see: "screen",
  mcp__vesper__dev_status: "self",
  mcp__vesper__dev_read: "self",
  mcp__vesper__dev_search: "self",
  mcp__vesper__dev_build: "self",
  mcp__vesper__change: "self",
  mcp__vesper__dev_restart: "self",
  Read: "vault.read",
  Glob: "vault.search",
  Grep: "vault.search",
  WebFetch: "web",
  WebSearch: "web",
};

const PALETTE = {
  gutter: tn.gutter,
  bgHighlight: tn.bgHighlight,
  fg: tn.fg,
  comment: tn.comment,
  font: FONT,
  group: {
    core: tn.magenta,
    vault: tn.blue,
    time: tn.yellow,
    action: tn.green,
    world: tn.cyan,
  },
};

const ACCENT = {
  idle: tn.cyan,
  listening: tn.cyan,
  thinking: tn.magenta,
  speaking: tn.green,
  offline: tn.comment,
};
const accentFor = (s) => ACCENT[s] || ACCENT.offline;

// Module scope: Übersicht loads the module once but may re-render. Keeping the
// engine and socket here means a re-render reattaches to the running animation
// instead of starting a second one. Resets only when the file is re-bundled.
let graph = null;
let boundCanvas = null;
let socket = null;
let retry = 0;
let live = { state: "idle", connected: false };

// The status line is updated imperatively rather than through React state.
// No other widget here uses React, and Übersicht 1.6 is not guaranteed to
// expose a hooks-capable React global — but ref callbacks work in every React
// version. This also means a socket event never re-renders the canvas.
let statusDot = null;
let statusText = null;

function paintStatus() {
  const label = live.connected ? live.state : "offline";
  if (statusText) statusText.textContent = label;
  if (statusDot) statusDot.style.background = accentFor(label);
}

function connect() {
  if (socket && (socket.readyState === 0 || socket.readyState === 1)) return;

  socket = new WebSocket(`ws://${HOST}:${PORT}/ws`);

  socket.onopen = () => {
    retry = 0;
    live = { ...live, connected: true };
    if (graph) graph.setState(live.state, true);
    paintStatus();
  };

  socket.onmessage = (ev) => {
    let e;
    try {
      e = JSON.parse(ev.data);
    } catch (_) {
      return;
    }
    if (e.kind === "state.change") {
      live = { ...live, state: e.payload.to };
      if (graph) graph.setState(e.payload.to, true);
      paintStatus();
    } else if (e.kind === "tool.call" && graph) {
      graph.pulse(TOOL_NODE[e.payload.name] || "core");
    }
  };

  socket.onclose = () => {
    live = { ...live, connected: false, state: "idle" };
    if (graph) graph.setState("idle", false);
    paintStatus();
    // Back off to 30s: the daemon is often simply not running, and this widget
    // sits on the desktop all day. Hammering it would burn battery for nothing.
    retry = Math.min(retry + 1, 6);
    setTimeout(connect, Math.min(30000, 1000 * Math.pow(2, retry - 1)));
  };

  socket.onerror = () => {
    try {
      socket.close();
    } catch (_) {}
  };
}

const attach = (el) => {
  if (!el || el === boundCanvas) return;
  if (graph) graph.destroy();
  boundCanvas = el;
  graph = createGraph(el, { spec: SPEC, links: LINKS, palette: PALETTE, accentFor });
  graph.setState(live.state, live.connected);
  connect();
};

export const className = `
  left: 0;
  right: 0;
  margin: 0 auto;
  /* Centre column. Wider than the other centre widgets on purpose: the graph
     is the point of this one, and a 380px card left it floating in dead space.

     NOTE: Ubersicht's origin sits ~38px below the top of the screen (under the
     menu bar), so every top: here is 38 less than the resulting on-screen
     position. This card is meant to occupy screen y 464-855, hence 426.
     Measured against weather, whose top: 232 renders at screen y 271.

     No backticks in here: this comment sits inside a template literal, and one
     would end the string. */
  top: 426px;
  width: 534px;
  ${card(tn.magenta, "600ms")}

  /* Belt and braces: the renderer already keeps every node inside the canvas,
     but clipping here means a layout mistake can never bleed over a
     neighbouring widget. */
  .wrap { position: relative; overflow: hidden; border-radius: 6px; }

  canvas {
    display: block;
    width: 100%;
    height: 337px;
  }

  .status {
    position: absolute;
    top: 0;
    right: 0;
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 9px;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: ${tn.comment};
  }
  .status i {
    width: 6px;
    height: 6px;
    border-radius: 6px;
    background: ${tn.comment};
    transition: background-color 300ms linear;
  }
`;

export const render = () => (
  <div>
    <h1>Vesper</h1>
    <div className="wrap">
      <div className="status">
        <i
          ref={(el) => {
            statusDot = el;
            paintStatus();
          }}
        />
        <span
          ref={(el) => {
            statusText = el;
            paintStatus();
          }}
        />
      </div>
      <canvas ref={attach} />
    </div>
  </div>
);
