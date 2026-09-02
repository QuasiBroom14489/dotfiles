// Today's calendar, via icalBuddy.
//
// Übersicht runs commands through a login shell, but a login shell started
// by a GUI app does not always pick up Homebrew's PATH — so icalBuddy is
// reached through an explicit prefix list rather than a bare name.
//
// Output contract (one event per line):  Title~09:30   or   Title~09:30 - 10:45
//   -nc   drop calendar-name headers          -sd   sort by date
//   -b '' no bullet                           -ps   property separator
//   -df ''  no date line (today only anyway)  -tf   24h times, parsed below
// -sd also emits a date header per group; with -df '' that is a bare ":" and a
// rule of dashes. Both are dropped by the parser, which keeps only lines that
// contain the separator.
//
// Calendar access is a TCC permission: the first run prompts, and until it
// is granted the command returns nothing and the widget reads "No events".
// stderr is redirected because Übersicht's runner returns HTTP 500 on the
// first byte of stderr and the widget then renders the error, not the output.

import { tn, card, BAR_CLEARANCE } from "./lib/tokyonight.js";

export const command =
  "PATH=/opt/homebrew/bin:/usr/local/bin:$PATH " +
  "icalBuddy -nc -nrd -ea -sd -b '' -ps '|~|' -df '' -tf '%H:%M' " +
  "-eep 'notes,url,location,attendees' -iep 'title,datetime' eventsToday 2>/dev/null";

export const refreshFrequency = 300000; // 5 min — calendars don't move fast

// This card is top-anchored above `golden-dome` in the right column, so an
// uncapped list would grow straight into it on a heavy day. Same cap and
// footer as focus.jsx and assignments.jsx.
const MAX_ITEMS = 8;

export const className = `
  right: 24px;
  top: ${BAR_CLEARANCE};
  width: 320px;
  ${card(tn.cyan, '120ms')}

  /* Widest label is "all-day". */
  .row .when { width: 50px; }
  .row.past { opacity: 0.35; }
  .row.next { color: ${tn.cyan}; }
  .row.next .when { color: inherit; }
  .allday { color: ${tn.yellow}; }
`;

// "09:30" or "09:30 - 10:45" → 570. Returns null for all-day events.
const startMinutes = (when) => {
  const m = /^(\d{1,2}):(\d{2})/.exec(when);
  return m ? Number(m[1]) * 60 + Number(m[2]) : null;
};

// Start time only. icalBuddy hands back "09:30" or "09:30 - 10:45", and the
// end of a range is both the least useful half at a glance and the thing that
// blows out the fixed-width time gutter.
const to12h = (when) =>
  when.split(" - ")[0].replace(/(\d{1,2}):(\d{2})/, (_, h, m) => {
    const hour = Number(h);
    const suffix = hour < 12 ? "a" : "p";
    const h12 = hour % 12 === 0 ? 12 : hour % 12;
    return m === "00" ? `${h12}${suffix}` : `${h12}:${m}${suffix}`;
  });

const parse = (output) =>
  String(output || "")
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.includes("~"))
    .map((line) => {
      // Split on the LAST separator — event titles occasionally contain "~".
      const i = line.lastIndexOf("~");
      return { title: line.slice(0, i).trim(), when: line.slice(i + 1).trim() };
    })
    .filter((e) => e.title);

export const render = ({ output }) => {
  const events = parse(output);
  const shown = events.slice(0, MAX_ITEMS);
  const now = new Date();
  const nowMin = now.getHours() * 60 + now.getMinutes();

  // First event that hasn't started yet gets the highlight. All-day events
  // sort first out of icalBuddy and are never "next".
  const nextIdx = events.findIndex((e) => {
    const s = startMinutes(e.when);
    return s !== null && s > nowMin;
  });

  return (
    <div>
      <h1>Today</h1>
      {shown.length === 0 ? (
        <div className="empty">No events.</div>
      ) : (
        shown.map((e, i) => {
          const s = startMinutes(e.when);
          let state = "";
          if (i === nextIdx) state = "next";
          else if (s !== null && s < nowMin) state = "past";

          return (
            <div className={`row ${state}`} key={`${e.when}-${e.title}-${i}`}>
              <span className={`when ${s === null ? "allday" : ""}`}>
                {s === null ? "all-day" : to12h(e.when)}
              </span>
              <span className="what">{e.title}</span>
            </div>
          );
        })
      )}
      {events.length > shown.length && (
        <div className="note">+{events.length - shown.length} more today</div>
      )}
    </div>
  );
};
