// System vitals — the trend SketchyBar's pills can't show.
//
// The bar's CPU/MEM pills give you the instantaneous number; this gives you
// the last few minutes of it, plus the two things the bar has no room for:
// disk headroom and whichever process is actually holding the memory.

import { tn, card, FONT } from "./lib/tokyonight.js";

export const command = "./lib/sysstats.sh";
export const refreshFrequency = 10000;

// History lives at module scope: Übersicht re-runs render() on each refresh but
// only loads the module once, so this survives between ticks. It resets when
// the widget is re-bundled (i.e. when you edit the file), which is fine.
const HISTORY_LEN = 36;
const history = [];

export const className = `
  left: 24px;
  top: 500px;
  width: 300px;
  ${card(tn.teal, "520ms")}

  .spark {
    display: flex;
    align-items: flex-end;
    gap: 2px;
    height: 34px;
    margin-bottom: 10px;
  }
  .spark i {
    flex: 1 1 0;
    min-width: 2px;
    border-radius: 1px;
    background: ${tn.teal};
    /* Every bar shifts up one slot per tick, so transitioning height turns a
       redraw into a scroll. */
    transition: height 700ms cubic-bezier(0.2, 0.7, 0.3, 1), background-color 700ms linear;
  }
  .spark i.warm { background: ${tn.yellow}; }
  .spark i.hot  { background: ${tn.red}; }
  .spark i.idle { background: ${tn.gutter}; height: 3px !important; }

  .stat { display: flex; align-items: center; gap: 8px; padding: 2px 0; }
  .stat .k {
    flex: 0 0 auto;
    width: 38px;
    font-size: 10px;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: ${tn.comment};
  }
  .stat .meter { flex: 1 1 auto; }
  .stat .v {
    flex: 0 0 auto;
    width: 34px;
    text-align: right;
    font-family: ${FONT};
    font-variant-numeric: tabular-nums;
    color: ${tn.fgDark};
  }

  .foot {
    margin-top: 9px;
    padding-top: 7px;
    border-top: 1px solid ${tn.bgHighlight};
    display: flex;
    justify-content: space-between;
    gap: 10px;
    font-size: 10.5px;
    color: ${tn.comment};
  }
  .foot .hog {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: ${tn.fgDark};
  }
`;

// Same thresholds the SketchyBar plugins use, so a pill turning red and a bar
// turning red mean the same thing.
const band = (v) => (v >= 90 ? "hot" : v >= 70 ? "warm" : v > 0 ? "" : "idle");
const meterColor = (v) => (v >= 90 ? tn.red : v >= 75 ? tn.yellow : tn.teal);

export const render = ({ output }) => {
  const [cpuS, memS, diskS, uptime, hog, hogGB] = String(output || "").trim().split("|");
  const cpu = Number(cpuS);
  if (Number.isNaN(cpu)) return <div />;
  const mem = Number(memS) || 0;
  const disk = Number(diskS) || 0;

  history.push(cpu);
  while (history.length > HISTORY_LEN) history.shift();

  // Left-pad so the chart fills from the right as samples arrive, rather than
  // starting wide and squashing.
  const bars = Array(HISTORY_LEN - history.length).fill(null).concat(history);

  return (
    <div>
      <h1>System · CPU {cpu}%</h1>

      <div className="spark">
        {bars.map((v, i) => (
          <i
            key={i}
            className={v === null ? "idle" : band(v)}
            style={{ height: `${v === null ? 0 : Math.max(6, Math.min(100, v))}%` }}
          />
        ))}
      </div>

      <div className="stat">
        <span className="k">Mem</span>
        <span className="meter">
          <i style={{ width: `${mem}%`, background: meterColor(mem) }} />
        </span>
        <span className="v">{mem}%</span>
      </div>

      <div className="stat">
        <span className="k">Disk</span>
        <span className="meter">
          <i style={{ width: `${disk}%`, background: meterColor(disk) }} />
        </span>
        <span className="v">{disk}%</span>
      </div>

      <div className="foot">
        <span>up {uptime}</span>
        <span className="hog">
          {hog} · {hogGB} GB
        </span>
      </div>
    </div>
  );
};
