// Tokyo Night (Night) — the same palette as ~/dotfiles/colors/tokyonight.sh,
// in the form the widgets need it (CSS hex, not 0xAARRGGBB).
//
// This file sits under lib/ deliberately. Übersicht's widget scanner skips
// any path containing /lib/, /src/ or /node_modules/, so a shared module
// here is NOT loaded as a (broken, render-less) widget — while browserify
// still bundles it into every widget that imports it. Keep shared code here.

export const tn = {
  bg: "#1a1b26",
  bgDark: "#16161e",
  bgHighlight: "#292e42",
  fg: "#c0caf5",
  fgDark: "#a9b1d6",
  gutter: "#3b4261",
  comment: "#565f89",
  blue: "#7aa2f7",
  cyan: "#7dcfff",
  green: "#9ece6a",
  magenta: "#bb9af7",
  red: "#f7768e",
  yellow: "#e0af68",
  orange: "#ff9e64",
  teal: "#1abc9c",
};

export const FONT = '"JetBrainsMono Nerd Font", "JetBrains Mono", ui-monospace, monospace';

// SketchyBar is 32px tall and sticky at the top, so nothing may sit above
// this line or it renders behind the bar.
export const BAR_CLEARANCE = "48px";

// Shared card chrome. `accent` colours the title rule and the left edge, so
// every widget reads as one system without repeating 40 lines of CSS.
//
// `delay` staggers the mount animation. Übersicht renders each widget as soon
// as its first command returns, so without a stagger they pop in at whatever
// order the shell happens to finish — giving each a fixed delay makes login
// look like one deliberate cascade instead of a race.
//
// The animation runs on mount only. A refresh re-renders the same element
// rather than remounting it, so the card does not re-animate every 30s.
export const card = (accent, delay = "0ms") => `
  font-family: ${FONT};
  font-size: 12px;
  line-height: 1.5;
  color: ${tn.fg};
  background: rgba(26, 27, 38, 0.82);
  -webkit-backdrop-filter: blur(24px) saturate(120%);
  border: 1px solid ${tn.gutter};
  border-left: 2px solid ${accent};
  border-radius: 8px;
  padding: 10px 14px 12px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.35);
  box-sizing: border-box;

  opacity: 0;
  animation: tnCardIn 560ms cubic-bezier(0.2, 0.7, 0.3, 1) ${delay} forwards;

  @keyframes tnCardIn {
    from { opacity: 0; transform: translateY(12px) scale(0.985); }
    to   { opacity: 1; transform: none; }
  }

  h1 {
    margin: 0 0 8px;
    padding-bottom: 6px;
    border-bottom: 1px solid ${tn.bgHighlight};
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: ${accent};
  }

  .empty {
    color: ${tn.comment};
    font-style: italic;
  }

  .row {
    display: flex;
    gap: 10px;
    align-items: baseline;
    padding: 2px 0;
  }

  .row .when {
    flex: 0 0 auto;
    text-align: right;
    color: ${tn.comment};
    font-variant-numeric: tabular-nums;
  }

  .row .what {
    flex: 1 1 auto;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* Horizontal meter. The fill transitions rather than jumping, so a refresh
     reads as movement instead of a flicker — which is the whole reason these
     are nicer to glance at than a number. */
  .meter {
    height: 4px;
    border-radius: 2px;
    background: ${tn.bgHighlight};
    overflow: hidden;
  }
  .meter > i {
    display: block;
    height: 100%;
    border-radius: 2px;
    background: ${accent};
    transition: width 700ms cubic-bezier(0.2, 0.7, 0.3, 1), background-color 700ms linear;
  }

  .chip {
    flex: 0 0 auto;
    padding: 0 5px;
    border-radius: 4px;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.04em;
    background: ${tn.bgHighlight};
    color: ${tn.fgDark};
  }

  .note {
    margin-top: 8px;
    color: ${tn.comment};
    font-size: 11px;
  }
`;

// Übersicht always paints the widget's root element, so a widget that needs to
// vanish completely (now-playing with nothing loaded) cannot put the card
// chrome there — render() has no way to unstyle it. Give the root this reset,
// keep positioning on it, and hang card() off an inner node instead.
export const SHELL = `
  background: none;
  border: none;
  box-shadow: none;
  padding: 0;
  -webkit-backdrop-filter: none;
`;

// Slow pulse for the single most urgent thing on screen. Opacity only —
// anything that moves on the desktop competes with the windows in front of it.
export const PULSE = `
  animation: tnPulse 2.4s ease-in-out infinite;
  @keyframes tnPulse {
    0%, 100% { opacity: 1; }
    50%      { opacity: 0.45; }
  }
`;
