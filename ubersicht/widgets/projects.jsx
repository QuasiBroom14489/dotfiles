// Projects — the shelf: what's open and what you touched last, one click to
// resume. Clicking a row goes through hammerspoon://project?name=…, the same
// path as Enter in the Hyper+J launcher (focus the window if it's already
// open, otherwise a new Ghostty window on its Zellij session).
//
// Data: lib/projects.sh → `proj status --tsv` (~0.4 s, read-only git).
// Placement: the gutter between the left column and vesper-graph on the
// 1920-wide Dell. Hidden below 1700 px, where that gutter is ~165 px wide.

import { run } from "uebersicht";
import { tn, card } from "./lib/tokyonight.js";

export const command = "./lib/projects.sh";
export const refreshFrequency = 60000;

const MAX_ROWS = 6;
const DAY = 86400;

export const className = `
  left: 348px;
  top: 426px;
  width: 320px;
  ${card(tn.cyan, "360ms")}

  @media (max-width: 1700px) { display: none; }

  .row {
    display: flex;
    align-items: baseline;
    gap: 8px;
    height: 18px;
    line-height: 18px;
    padding: 0 4px;
    margin: 0 -4px;
    border-radius: 4px;
    cursor: pointer;
    transition: background-color 120ms linear;
  }
  .row:hover { background: ${tn.bgHighlight}; }
  .row:hover .name { color: ${tn.cyan}; }

  .dot { flex: 0 0 1ch; }
  .dot.live { color: ${tn.green}; }
  .dot.exited { color: ${tn.yellow}; }
  .dot.none { color: ${tn.gutter}; }

  .name { flex: 0 0 auto; max-width: 132px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .what {
    flex: 1 1 auto; min-width: 0;
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
    color: ${tn.comment}; font-size: 11px;
  }
  .dirty { flex: 0 0 auto; color: ${tn.yellow}; font-size: 11px; }
  .when { flex: 0 0 auto; color: ${tn.comment}; font-size: 11px; font-variant-numeric: tabular-nums; }
  .when.open { color: ${tn.green}; }

  .foot { margin-top: 6px; color: ${tn.comment}; font-size: 11px; }
`;

const ago = (epoch) => {
  const s = Math.max(0, Date.now() / 1000 - Number(epoch || 0));
  if (!epoch || epoch === "0") return "";
  if (s < 3600) return Math.max(1, Math.round(s / 60)) + "m";
  if (s < DAY) return Math.round(s / 3600) + "h";
  if (s < 14 * DAY) return Math.round(s / DAY) + "d";
  if (s < 60 * DAY) return Math.round(s / (7 * DAY)) + "w";
  return Math.round(s / (30 * DAY)) + "mo";
};

// Slugs are [a-z0-9-]; anything else never reaches the shell.
const resume = (slug) => {
  if (!/^[a-z0-9][a-z0-9-]*$/.test(slug)) return;
  run(`open -g 'hammerspoon://project?name=${slug}' >/dev/null 2>&1 &`).catch(() => {});
};

export const render = ({ output, error }) => {
  const all = String(output || "")
    .split("\n")
    .map((l) => l.split("\t"))
    .filter((c) => c.length >= 10)
    .map(([slug, path, kind, type, state, clients, dirty, branch, last, parent, note]) => ({
      slug, kind, type, state, clients: +clients, dirty: dirty === "-" ? 0 : +dirty, last, parent: parent === "-" ? null : parent, note: note || "",
    }));

  // proj already sorts live → saved → new, newest first. Side worktrees only
  // earn a row while they're open.
  const rows = all.filter((p) => p.state === "live" || !p.parent).slice(0, MAX_ROWS);
  const live = all.filter((p) => p.state === "live").length;

  return (
    <div>
      <h1>Projects</h1>
      {error ? (
        <div className="empty">proj status failed</div>
      ) : rows.length === 0 ? (
        <div className="empty">No projects yet — Hyper+J, then Ctrl-N.</div>
      ) : (
        rows.map((p) => (
          <div className="row" key={p.slug} onClick={() => resume(p.slug)} title={p.note || p.slug}>
            <span className={`dot ${p.state}`}>{p.state === "live" ? "●" : p.state === "exited" ? "◐" : "○"}</span>
            <span className="name">{p.slug}</span>
            <span className="what">{p.note || (p.kind === "course" ? "course · " + p.type : p.type)}</span>
            {p.dirty > 0 && <span className="dirty">+{p.dirty}</span>}
            <span className={`when ${p.clients > 0 ? "open" : ""}`}>{p.clients > 0 ? "open" : ago(p.last)}</span>
          </div>
        ))
      )}
      <div className="foot">
        {live} open · {all.length} projects · Hyper+J for all
      </div>
    </div>
  );
};
