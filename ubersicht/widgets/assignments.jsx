// What's actually due, across every class.
//
// The parsing lives in lib/assignments.sh — same reasoning as focus.jsx: the
// vault path has spaces, sits in iCloud, and the regex work is far easier to
// read in awk than escaped inside a JS string inside a shell command.

import { tn, card, PULSE } from "./lib/tokyonight.js";

export const command = "./lib/assignments.sh";
export const refreshFrequency = 600000; // 10 min — Canvas syncs hourly at best

// The script hands back the whole semester (100+ rows). Anything past the next
// handful is a planning question, not a glanceable one.
const MAX_ITEMS = 7;

export const className = `
  right: 24px;
  bottom: 24px;
  width: 320px;
  ${card(tn.yellow, "360ms")}

  .row { align-items: center; }
  .row .what { font-size: 11.5px; }
  .course {
    flex: 0 0 auto;
    width: 68px;
    font-size: 10px;
    letter-spacing: 0.04em;
    color: ${tn.comment};
  }
  .due { width: 46px; text-align: right; }

  .overdue .due   { background: ${tn.red};    color: ${tn.bgDark}; }
  .today .due     { background: ${tn.orange}; color: ${tn.bgDark}; }
  .soon .due      { background: ${tn.yellow}; color: ${tn.bgDark}; }

  .overdue .what  { color: ${tn.red}; }
  .today .what    { color: ${tn.fg}; }
  .later .what    { color: ${tn.fgDark}; }

  /* Exactly one thing pulses: whatever is most overdue. More than one and the
     card turns into a slot machine. */
  .row:first-of-type.overdue .due { ${PULSE} }
`;

// Whole-day difference, so "tomorrow" doesn't flip to "today" at 00:01.
const daysUntil = (iso) => {
  const [y, m, d] = iso.split("-").map(Number);
  const due = new Date(y, m - 1, d);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return Math.round((due - today) / 86400000);
};

const dueLabel = (n) => {
  if (n < 0) return `${-n}d ago`;
  if (n === 0) return "today";
  if (n === 1) return "tmrw";
  return `${n}d`;
};

const urgency = (n) => (n < 0 ? "overdue" : n === 0 ? "today" : n <= 3 ? "soon" : "later");

export const render = ({ output }) => {
  const rows = String(output || "")
    .split("\n")
    .map((l) => l.split("\t"))
    .filter((p) => p.length >= 3)
    .map(([due, course, title]) => ({ due, course, title }));

  const shown = rows.slice(0, MAX_ITEMS);
  const overdue = rows.filter((r) => daysUntil(r.due) < 0).length;

  return (
    <div>
      <h1>Due</h1>
      {shown.length === 0 ? (
        <div className="empty">Nothing on the board.</div>
      ) : (
        shown.map((r, i) => {
          const n = daysUntil(r.due);
          return (
            <div className={`row ${urgency(n)}`} key={`${r.due}-${r.title}-${i}`}>
              <span className="course">{r.course}</span>
              <span className="what" title={r.title}>{r.title}</span>
              <span className="chip due">{dueLabel(n)}</span>
            </div>
          );
        })
      )}
      {rows.length > shown.length && (
        <div className="note">
          +{rows.length - shown.length} more this semester
          {overdue > 0 && ` · ${overdue} overdue`}
        </div>
      )}
    </div>
  );
};
