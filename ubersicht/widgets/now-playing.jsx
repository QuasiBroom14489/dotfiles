// Now playing, with an equaliser that actually reflects the player state.
//
// This widget disappears when nothing is loaded, so its chrome hangs off an
// inner .card rather than the root — see SHELL in lib/tokyonight.js.

import { tn, card, SHELL, FONT } from "./lib/tokyonight.js";

export const command = "./lib/nowplaying.sh";
export const refreshFrequency = 5000;

// Five bars, each with its own period and phase. Prime-ish durations keep them
// from re-syncing into a single pulse the way equal durations would.
const BARS = [
  { dur: "0.62s", delay: "0.00s", h: 100 },
  { dur: "0.47s", delay: "0.18s", h: 70 },
  { dur: "0.71s", delay: "0.07s", h: 100 },
  { dur: "0.53s", delay: "0.26s", h: 85 },
  { dur: "0.66s", delay: "0.12s", h: 60 },
];

export const className = `
  left: 0;
  right: 0;
  margin: 0 auto;
  bottom: 24px;
  width: 380px;
  ${SHELL}

  .card { ${card(tn.green, "440ms")} }

  .head { display: flex; align-items: center; gap: 10px; }

  .eq {
    flex: 0 0 auto;
    display: flex;
    align-items: flex-end;
    gap: 2px;
    height: 16px;
  }
  .eq i {
    width: 3px;
    border-radius: 1px;
    background: ${tn.green};
    transform-origin: bottom;
    animation-name: npBar;
    animation-timing-function: ease-in-out;
    animation-iteration-count: infinite;
    animation-direction: alternate;
  }
  /* Paused, the bars freeze mid-motion rather than vanishing — the card still
     tells you what is cued up, it just stops implying sound. */
  .paused .eq i { animation-play-state: paused; opacity: 0.4; }

  @keyframes npBar {
    from { transform: scaleY(0.22); }
    to   { transform: scaleY(1); }
  }

  .title {
    flex: 1 1 auto;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-family: ${FONT};
    font-weight: 700;
    color: ${tn.fg};
  }
  .artist {
    margin-top: 1px;
    color: ${tn.comment};
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .bar { margin-top: 9px; display: flex; align-items: center; gap: 8px; }
  .bar .meter { flex: 1 1 auto; }
  .bar .t {
    flex: 0 0 auto;
    font-size: 10px;
    color: ${tn.comment};
    font-variant-numeric: tabular-nums;
  }
`;

const mmss = (secs) => {
  const s = Math.max(0, Math.floor(secs));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
};

export const render = ({ output }) => {
  const line = String(output || "").trim();
  if (!line) return <div />;

  const [state, title, artist, pos, dur] = line.split("|");
  if (!title) return <div />;

  const position = Number(pos) || 0;
  const duration = Number(dur) || 0;
  const pct = duration > 0 ? Math.min(100, (position / duration) * 100) : 0;
  const playing = state === "playing";

  return (
    <div className={`card ${playing ? "" : "paused"}`}>
      <div className="head">
        <span className="eq">
          {BARS.map((b, i) => (
            <i
              key={i}
              style={{
                height: `${b.h}%`,
                animationDuration: b.dur,
                animationDelay: b.delay,
              }}
            />
          ))}
        </span>
        <span className="title" title={title}>
          {title}
        </span>
      </div>
      <div className="artist">{artist}</div>
      <div className="bar">
        <span className="t">{mmss(position)}</span>
        <span className="meter">
          <i style={{ width: `${pct}%` }} />
        </span>
        <span className="t">{mmss(duration)}</span>
      </div>
    </div>
  );
};
