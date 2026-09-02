// Current focus — the open "## Current Sprint" checkboxes across LifeVault's
// five goal files, grouped by goal.
//
// The extraction lives in lib/current-sprint.sh rather than inline here: the
// vault path contains spaces and lives in iCloud, which is exactly the kind
// of quoting that goes wrong once it is embedded in a JS string that is
// embedded in a shell command.

import { tn, card } from "./lib/tokyonight.js";

export const command = "./lib/current-sprint.sh";
export const refreshFrequency = 120000;

// Anything past this and the card stops being glanceable.
const MAX_ITEMS = 8;

export const className = `
  left: 24px;
  bottom: 24px;
  width: 300px;
  ${card(tn.magenta, '240ms')}

  .goal {
    margin-top: 8px;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: ${tn.magenta};
  }
  .goal:first-of-type { margin-top: 0; }

  .item {
    display: flex;
    gap: 8px;
    padding: 1px 0;
  }
  .item .box { color: ${tn.comment}; }
  .item .text { flex: 1 1 auto; }

  code {
    font-family: inherit;
    font-size: 11px;
    color: ${tn.orange};
    background: ${tn.bgHighlight};
    border-radius: 3px;
    padding: 0 3px;
  }

  .more { margin-top: 6px; color: ${tn.comment}; font-size: 11px; }
`;

// Render the little markdown that actually shows up in these lines: inline
// code spans, and wikilinks reduced to their display text.
const richText = (text, key) => {
  const clean = text.replace(/\[\[([^\]|]+\|)?([^\]]+)\]\]/g, "$2");
  return clean.split(/(`[^`]+`)/g).map((part, i) =>
    part.startsWith("`") && part.endsWith("`") && part.length > 1 ? (
      <code key={`${key}-${i}`}>{part.slice(1, -1)}</code>
    ) : (
      <span key={`${key}-${i}`}>{part}</span>
    )
  );
};

export const render = ({ output }) => {
  const rows = String(output || "")
    .split("\n")
    .map((l) => l.split("\t"))
    .filter((p) => p.length >= 2 && p[1].trim())
    .map(([goal, item]) => ({ goal: goal.trim(), item: item.trim() }));

  const shown = rows.slice(0, MAX_ITEMS);
  const hidden = rows.length - shown.length;

  // Group consecutively — the script already emits one goal's items together.
  const groups = [];
  shown.forEach((r) => {
    const last = groups[groups.length - 1];
    if (last && last.goal === r.goal) last.items.push(r.item);
    else groups.push({ goal: r.goal, items: [r.item] });
  });

  return (
    <div>
      <h1>Current Sprint</h1>
      {groups.length === 0 ? (
        <div className="empty">Nothing open. Set one on Monday.</div>
      ) : (
        groups.map((g) => (
          <div key={g.goal}>
            <div className="goal">{g.goal}</div>
            {g.items.map((item, i) => (
              <div className="item" key={`${g.goal}-${i}`}>
                <span className="box">▢</span>
                <span className="text">{richText(item, `${g.goal}-${i}`)}</span>
              </div>
            ))}
          </div>
        ))
      )}
      {hidden > 0 && <div className="more">+{hidden} more</div>}
    </div>
  );
};
