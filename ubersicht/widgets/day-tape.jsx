// Day progress as a punch card.
//
// 24 columns, one per hour, each split into four quarter-hour cells. Cells
// behind you are lit, cells ahead are dim, and a playhead sweeps across.
//
// Two decisions worth keeping:
//
//   * Colour encodes the phase of day, not progress. The lit portion runs
//     muted -> cyan -> blue -> magenta as night becomes morning, afternoon and
//     evening, so the shape of the day is legible at a glance rather than being
//     one undifferentiated bar.
//   * The playhead moves by CSS transition, not by animation. Its duration
//     matches refreshFrequency, so each tick hands off to the next and the line
//     glides continuously instead of stepping. Nothing here pulses — the
//     assignments card owns the one pulse on this desktop.

import { tn, card, FONT } from "./lib/tokyonight.js";
import { coursesOn, minutesOf, label12h } from "./lib/schedule.js";

export const command = "date '+%H:%M:%S'";
export const refreshFrequency = 20000;

const MINUTES = 1440;
const HOURS = Array.from({ length: 24 }, (_, i) => i);
const QUARTERS = [0, 1, 2, 3];

// Which colour an hour belongs to. Boundaries are the ordinary ones rather
// than real sunrise/sunset — that would mean a second network dependency for a
// widget whose whole point is that it works offline.
const phaseColor = (hour) => {
  if (hour < 6 || hour >= 22) return tn.comment;
  if (hour < 12) return tn.cyan;
  if (hour < 18) return tn.blue;
  return tn.magenta;
};

export const className = `
  left: 24px;
  top: 300px;
  width: 300px;
  ${card(tn.cyan, "160ms")}

  .hero {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    margin-bottom: 10px;
  }
  .pct {
    font-family: ${FONT};
    font-size: 30px;
    font-weight: 700;
    line-height: 1;
    color: ${tn.fg};
    font-variant-numeric: tabular-nums;
  }
  .pct sup { font-size: 13px; font-weight: 400; color: ${tn.comment}; margin-left: 1px; }
  .left { font-size: 11px; color: ${tn.fgDark}; font-variant-numeric: tabular-nums; }

  .tape { position: relative; }

  /* Class starts, marked at their exact position. Only the start: the
     registrar line gives no end times and this card will not invent them. */
  .ticks { position: relative; height: 7px; }
  .tick {
    position: absolute;
    top: 1px;
    width: 2px;
    height: 5px;
    border-radius: 1px;
    margin-left: -1px;
  }

  /* Fixed table layout so all 24 columns are exactly equal. Flex and grid both
     let the last column collapse here - see weather.jsx for the same fight. */
  .grid { display: table; table-layout: fixed; width: 100%; }
  .col { display: table-cell; padding: 0 0.5px; }
  .q {
    display: block;
    height: 6px;
    margin-bottom: 1px;
    border-radius: 1px;
    transition: opacity 900ms linear, box-shadow 900ms linear;
  }
  .q.now { box-shadow: 0 0 6px currentColor; }

  .playhead {
    position: absolute;
    top: 0;
    bottom: 0;
    width: 1px;
    margin-left: -0.5px;
    background: ${tn.fg};
    box-shadow: 0 0 6px ${tn.fg};
    transition: left 20s linear;
  }
  .playhead::after {
    content: "";
    position: absolute;
    top: -3px;
    left: -2px;
    width: 5px;
    height: 5px;
    border-radius: 50%;
    background: ${tn.fg};
  }

  .axis {
    display: flex;
    justify-content: space-between;
    margin-top: 5px;
    font-size: 9px;
    color: ${tn.comment};
  }

  .foot {
    margin-top: 9px;
    padding-top: 7px;
    border-top: 1px solid ${tn.bgHighlight};
    font-size: 10.5px;
    color: ${tn.comment};
  }
  .foot b { color: ${tn.fgDark}; font-weight: 400; }
`;

const hm = (mins) => {
  const h = Math.floor(mins / 60);
  const m = Math.round(mins % 60);
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
};

export const render = ({ output }) => {
  const [hh, mm, ss] = String(output || "").trim().split(":").map(Number);
  if (Number.isNaN(hh)) return <div />;

  const nowMin = hh * 60 + mm + (ss || 0) / 60;
  const pct = (nowMin / MINUTES) * 100;
  const classes = coursesOn(new Date());
  const next = classes.find((c) => minutesOf(c.start) > nowMin);

  return (
    <div>
      <h1>Day</h1>

      <div className="hero">
        <span className="pct">
          {Math.floor(pct)}
          <sup>%</sup>
        </span>
        <span className="left">{hm(MINUTES - nowMin)} left</span>
      </div>

      <div className="tape">
        <div className="ticks">
          {classes.map((c) => (
            <span
              className="tick"
              key={c.code + c.start}
              style={{
                left: `${(minutesOf(c.start) / MINUTES) * 100}%`,
                background: tn[c.accent] || tn.fg,
              }}
            />
          ))}
        </div>

        <div className="grid">
          {HOURS.map((h) => (
            <span className="col" key={h}>
              {QUARTERS.map((q) => {
                const cellStart = h * 60 + q * 15;
                const past = cellStart + 15 <= nowMin;
                const isNow = !past && cellStart <= nowMin;
                const color = phaseColor(h);
                return (
                  <span
                    className={`q ${isNow ? "now" : ""}`}
                    key={q}
                    style={{
                      background: color,
                      color, // currentColor drives the glow on the live cell
                      opacity: isNow ? 1 : past ? 0.85 : 0.16,
                    }}
                  />
                );
              })}
            </span>
          ))}
        </div>

        <span className="playhead" style={{ left: `${pct}%` }} />
      </div>

      <div className="axis">
        <span>12a</span>
        <span>6a</span>
        <span>12p</span>
        <span>6p</span>
        <span>12a</span>
      </div>

      <div className="foot">
        {next ? (
          <span>
            <b>{next.name}</b> in {hm(minutesOf(next.start) - nowMin)}
          </span>
        ) : (
          <span>No more classes today.</span>
        )}
      </div>
    </div>
  );
};
