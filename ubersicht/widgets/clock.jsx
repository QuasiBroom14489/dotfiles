// The centrepiece: time, date, and how far through the semester you are.
//
// Centred with `left: 0; right: 0; margin: auto` rather than
// `left: 50%; transform: translateX(-50%)`, because the shared card animates
// `transform` on mount and the two would fight.

import { tn, card, FONT, BAR_CLEARANCE } from "./lib/tokyonight.js";
import { SEMESTER_START, semesterWeek } from "./lib/schedule.js";

// Seconds come from the shell rather than the webview's own Date so the card
// cannot drift after a sleep/wake — same reason class-strip does it.
export const command = "date '+%H:%M:%S|%A|%B %-d'";
export const refreshFrequency = 1000;

// Fall 2026: classes start Aug 25, last final is Dec 16.
const SEMESTER_END = new Date(2026, 11, 16);
const SEMESTER_DAYS = Math.round((SEMESTER_END - SEMESTER_START) / 86400000);

export const className = `
  left: 0;
  right: 0;
  margin: 0 auto;
  top: ${BAR_CLEARANCE};
  width: 360px;
  text-align: center;
  ${card(tn.fg, "80ms")}

  h1 { border-bottom: none; padding-bottom: 0; margin-bottom: 2px; color: ${tn.comment}; }

  .time {
    font-family: ${FONT};
    font-size: 46px;
    font-weight: 700;
    line-height: 1.05;
    letter-spacing: 0.02em;
    color: ${tn.fg};
    font-variant-numeric: tabular-nums;
  }
  .time .sec {
    font-size: 20px;
    font-weight: 400;
    color: ${tn.blue};
    vertical-align: 6px;
    margin-left: 2px;
  }
  /* The colons carry the tick. A blink is the one animation here that is
     information rather than decoration — it says the widget is live. */
  .time .colon { animation: clockBlink 1s step-end infinite; }
  @keyframes clockBlink { 50% { opacity: 0.25; } }

  .date {
    margin-top: 2px;
    font-size: 12px;
    color: ${tn.fgDark};
  }

  .sem {
    margin-top: 10px;
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 10px;
    letter-spacing: 0.04em;
    color: ${tn.comment};
    font-variant-numeric: tabular-nums;
  }
  .sem .meter { flex: 1 1 auto; }
  .sem .meter > i { background: ${tn.blue}; }
`;

export const render = ({ output }) => {
  const [time, weekday, date] = String(output || "").trim().split("|");
  if (!time) return <div />;
  const [hh, mm, ss] = time.split(":");

  const now = new Date();
  const elapsed = Math.round((now - SEMESTER_START) / 86400000);
  const pct = Math.max(0, Math.min(100, (elapsed / SEMESTER_DAYS) * 100));

  return (
    <div>
      <h1>Week {semesterWeek(now)}</h1>
      <div className="time">
        {hh}
        <span className="colon">:</span>
        {mm}
        <span className="sec">{ss}</span>
      </div>
      <div className="date">
        {weekday}, {date}
      </div>
      <div className="sem">
        <span>{pct.toFixed(0)}%</span>
        <span className="meter">
          <i style={{ width: `${pct}%` }} />
        </span>
        <span>{Math.max(0, SEMESTER_DAYS - elapsed)}d left</span>
      </div>
    </div>
  );
};
