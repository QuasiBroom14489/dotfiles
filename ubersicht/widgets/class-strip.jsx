// Today's classes — Fall 2026.
//
// The course list is static data (lib/schedule.js), so the shell command is
// just a clock tick: it gives us the time from the same source of truth the
// rest of the rice uses, and re-renders the "now / next" highlight without
// trusting the webview's own timer to stay awake across sleep.

import { tn, card, BAR_CLEARANCE } from "./lib/tokyonight.js";
import { coursesOn, semesterWeek, minutesOf, label12h } from "./lib/schedule.js";

export const command = "date +%w:%H:%M";
export const refreshFrequency = 30000;

export const className = `
  left: 24px;
  top: ${BAR_CLEARANCE};
  width: 300px;
  ${card(tn.blue, '0ms')}

  /* Widest label is "12:30pm". */
  .row .when  { width: 56px; }
  .row.past   { opacity: 0.38; }
  .row.now    { color: ${tn.green}; }
  .row.now .when,
  .row.next .when { color: inherit; }
  .row.next   { color: ${tn.blue}; }
  .code {
    color: ${tn.comment};
    font-size: 10px;
    letter-spacing: 0.06em;
  }
  .row.now .code, .row.next .code { color: inherit; opacity: 0.75; }
`;

const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

// A class counts as "now" for this long after it starts. The registrar line
// gives no end times, so this is a display window, not a real duration.
const NOW_WINDOW = 75;

export const render = ({ output }) => {
  const [dayStr, hh, mm] = String(output || "").trim().split(":");
  const day = Number(dayStr);
  if (Number.isNaN(day)) return <div />;

  const nowMin = Number(hh) * 60 + Number(mm);
  const today = new Date();
  const classes = coursesOn(today);

  // The first class that hasn't started yet is "next"; anything inside its
  // display window is "now". Everything earlier is dimmed.
  const nextIdx = classes.findIndex((c) => minutesOf(c.start) > nowMin);

  return (
    <div>
      <h1>
        Week {semesterWeek(today)} · {DAYS[day]}
      </h1>
      {classes.length === 0 ? (
        <div className="empty">No classes today.</div>
      ) : (
        classes.map((c, i) => {
          const start = minutesOf(c.start);
          let state = "";
          if (nowMin >= start && nowMin < start + NOW_WINDOW) state = "now";
          else if (i === nextIdx) state = "next";
          else if (start < nowMin) state = "past";

          return (
            <div className={`row ${state}`} key={c.code + c.start}>
              <span className="when">{label12h(c.start)}</span>
              <span className="what">
                {c.name}
                <br />
                <span className="code">{c.code}</span>
              </span>
            </div>
          );
        })
      )}
    </div>
  );
};
