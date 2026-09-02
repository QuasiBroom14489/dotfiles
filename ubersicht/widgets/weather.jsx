// Weather, with today's temperature curve rather than just a number.
//
// Sits directly under the clock at the same width so the two read as one
// stacked unit rather than two unrelated boxes.

import { tn, card, FONT } from "./lib/tokyonight.js";

export const command = "./lib/weather.sh";
export const refreshFrequency = 1800000; // 30 min; wttr.in asks you not to hammer it

// Nerd Font weather glyphs (nf-weather-*, U+E3xx). Written as escapes rather
// than pasted characters so the file survives any editor that is unsure about
// private-use codepoints. JetBrains Mono Nerd Font carries the whole range.
const ICONS = {
  sun: "\ue30d",
  moon: "\ue32b",
  partly: "\ue302",
  cloud: "\ue312",
  fog: "\ue313",
  rain: "\ue318",
  snow: "\ue31a",
  storm: "\ue31d",
};

// WWO condition codes, grouped. The long tail of sleet/drizzle variants all
// land in rain or snow, which is the only distinction worth drawing at a glance.
const GROUPS = [
  [[113], "clear"],
  [[116], "partly"],
  [[119, 122], "cloud"],
  [[143, 248, 260], "fog"],
  [[200, 386, 389, 392, 395], "storm"],
  [[179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329,
    332, 335, 338, 350, 368, 371, 374, 377], "snow"],
];

const kindOf = (code) => {
  const n = Number(code);
  for (const [codes, kind] of GROUPS) if (codes.includes(n)) return kind;
  return "rain"; // everything remaining in the table is some flavour of wet
};

const iconFor = (code, night) => {
  const kind = kindOf(code);
  if (kind === "clear") return night ? ICONS.moon : ICONS.sun;
  if (kind === "partly") return ICONS.partly;
  if (kind === "cloud") return ICONS.cloud;
  if (kind === "fog") return ICONS.fog;
  if (kind === "storm") return ICONS.storm;
  if (kind === "snow") return ICONS.snow;
  return ICONS.rain;
};

const colorFor = (kind) =>
  ({ clear: tn.yellow, partly: tn.yellow, cloud: tn.comment, fog: tn.comment,
     storm: tn.magenta, snow: tn.cyan }[kind] || tn.blue);

export const className = `
  left: 0;
  right: 0;
  margin: 0 auto;
  top: 232px;
  width: 360px;
  ${card(tn.orange, "200ms")}

  .now { display: flex; align-items: center; gap: 12px; }
  .icon {
    flex: 0 0 auto;
    font-family: ${FONT};
    font-size: 30px;
    line-height: 1;
    /* Barely-there drift. On a desktop this reads as "alive"; any more and it
       competes with whatever window is in front of it. */
    animation: wxFloat 5s ease-in-out infinite;
  }
  @keyframes wxFloat {
    0%, 100% { transform: translateY(0); }
    50%      { transform: translateY(-3px); }
  }

  .temp {
    font-size: 26px;
    font-weight: 700;
    color: ${tn.fg};
    font-variant-numeric: tabular-nums;
  }
  .temp sup { font-size: 12px; font-weight: 400; color: ${tn.comment}; }
  .desc { flex: 1 1 auto; text-align: right; color: ${tn.fgDark}; font-size: 11px; }
  .desc .sub { display: block; color: ${tn.comment}; font-size: 10px; margin-top: 2px; }

  /* Today's curve: one column per 3-hour slot, height scaled between today's
     min and max so the shape is readable even on a flat day. */
  /* A fixed table layout, after both flex and grid let the last column
     collapse to a third of the others. With table-layout: fixed the browser
     divides the width equally and ignores content entirely, which is exactly
     the guarantee a column chart needs.
     (No backticks in comments in here - the whole block is a template literal
     and a stray backtick would end it mid-CSS.) */
  .curve {
    margin-top: 10px;
    display: table;
    table-layout: fixed;
    width: 100%;
  }
  .curve .slot {
    display: table-cell;
    vertical-align: bottom;
    text-align: center;
    padding: 0 1.5px;
  }
  .curve .barwrap { display: flex; align-items: flex-end; height: 34px; }
  .curve .bar {
    width: 100%;
    border-radius: 2px 2px 0 0;
    transition: height 800ms cubic-bezier(0.2, 0.7, 0.3, 1);
  }
  .curve .hr {
    display: block;
    margin-top: 3px;
    font-size: 9px;
    color: ${tn.comment};
    border-top: 2px solid transparent;
  }
  .curve .slot.now .hr { color: ${tn.orange}; border-top-color: ${tn.orange}; }

  .foot {
    margin-top: 8px;
    padding-top: 7px;
    border-top: 1px solid ${tn.bgHighlight};
    display: flex;
    justify-content: space-between;
    font-size: 10.5px;
    color: ${tn.comment};
  }
`;

const hourLabel = (h) => (h === 0 ? "12a" : h < 12 ? `${h}a` : h === 12 ? "12p" : `${h - 12}p`);

export const render = ({ output }) => {
  const line = String(output || "").trim();
  if (!line) return <div />;

  const [temp, feels, desc, code, humidity, wind, dir, max, min, hourly] = line.split("|");
  if (!temp) return <div />;

  const slots = String(hourly || "")
    .split(",")
    .filter(Boolean)
    .map((s) => {
      const [h, t, c] = s.split(":");
      return { hour: Number(h), temp: Number(t), code: c };
    });

  const lo = Math.min(...slots.map((s) => s.temp), Number(min));
  const hi = Math.max(...slots.map((s) => s.temp), Number(max));
  const span = Math.max(1, hi - lo);
  const nowHour = new Date().getHours();
  const night = nowHour < 6 || nowHour >= 20;

  return (
    <div>
      <h1>Weather</h1>
      <div className="now">
        <span className="icon" style={{ color: colorFor(kindOf(code)) }}>
          {iconFor(code, night)}
        </span>
        <span className="temp">
          {temp}
          <sup>°F</sup>
        </span>
        <span className="desc">
          {desc}
          <span className="sub">
            feels {feels}° · {humidity}% · {wind}mph {dir}
          </span>
        </span>
      </div>

      <div className="curve">
        {slots.map((s) => {
          // Each 3-hour slot owns the window starting at its own hour.
          const isNow = nowHour >= s.hour && nowHour < s.hour + 3;
          return (
            <span className={`slot ${isNow ? "now" : ""}`} key={s.hour}>
              <span className="barwrap">
                <span
                  className="bar"
                  style={{
                    height: `${8 + ((s.temp - lo) / span) * 22}px`,
                    background: colorFor(kindOf(s.code)),
                    opacity: isNow ? 1 : 0.55,
                  }}
                />
              </span>
              <span className="hr">{hourLabel(s.hour)}</span>
            </span>
          );
        })}
      </div>

      <div className="foot">
        <span>
          high {max}° · low {min}°
        </span>
        <span>wttr.in</span>
      </div>
    </div>
  );
};
