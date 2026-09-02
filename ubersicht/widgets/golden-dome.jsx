// The Golden Dome, rendered as rotating ASCII. Purely decorative.
//
// A donut.c-style renderer: walk a parametric surface, rotate it, project it
// with 1/z, light it with a dot product against a fixed light, and keep the
// nearest sample per character cell in a z-buffer.
//
// Why it can't just be a spinning dome: a surface of revolution turned about
// its own axis of symmetry produces an identical image every frame. The
// meridian ribs and the colonnade are the only reason the rotation is visible
// at all - they are load-bearing, not ornament.
//
// The animation does NOT come from refreshFrequency. Shelling out 15 times a
// second to move a picture would be indefensible, so the frame loop lives in
// the webview and writes straight into the <pre>. The command refresh is set
// an hour out and exists only so Ubersicht mounts the widget.

import { tn, card, FONT } from "./lib/tokyonight.js";

export const command = "true";
export const refreshFrequency = 3600000;

// ── Grid and projection ─────────────────────────────────────────────
const COLS = 52;
const ROWS = 34;

// 8px, not 9: the glyph advance is 0.684em, so 52 columns at 9px is 320px of
// text inside a 292px card - it overflowed. At 8px the same grid is 284px wide.
const FONT_PX = 8;
const LINE_PX = 8;
// JetBrains Mono Nerd Font advances 0.68em (measured, not assumed - the plain
// <pre>. ASPECT must be cellWidth/cellHeight or the object comes out distorted:
// the first version hardcoded 0.5 against a 6.5x10 cell, which squashed the
// dome vertically and is why it read wide and squat. Derive it, don't guess.
const CHAR_W = FONT_PX * 0.684;
const ASPECT = CHAR_W / LINE_PX;

const K2 = 11;           // camera distance; large enough that the object's own
                         // depth barely changes scale - at 5 the near side of
                         // the drum flared out past the cornice
const K1 = 176;          // projection scale (16 x K2), sized so the object fits ROWS
const TILT = 0.13;       // near-level. Enough tilt to read as 3D; at 0.30 the
                         // dome looked down onto the drum and squashed it away

// Darkest to brightest. From donut.c, which picked them by apparent ink
// coverage rather than alphabetical accident.
const RAMP = ".,-~:;=!*#$@";
const LUM_FLOOR = 0.18;  // below this a sample is dropped rather than drawn as
                         // '.', which is what kept fuzzing the silhouette
const GAMMA = 0.8;

// ── Geometry ────────────────────────────────────────────────────────
const R = 1.0;           // radius at the dome's springing
const DOME_H = 1.35;     // the real dome is markedly taller than a hemisphere
const DOME_N = 2.6;      // superellipse exponent; 2 is an ellipse, >2 fills the shoulder
const DRUM = 0.55;       // drum height below the springing
const RIBS = 14;
const COLUMNS = 8;
const LANTERN_Y = DOME_H;
const TAU = Math.PI * 2;

const Y_CENTRE = 0.75;   // midpoint of the object's full vertical extent
const BASE_DTH = 0.055;  // angular step at unit radius; scaled by 1/rho below

// Light from above and in front, in camera space.
const LX = 0, LY = 0.55, LZ = 0.84;

// Flip to check that a unit sphere renders circular rather than oval. Any
// judgement about proportion is meaningless until this looks right.
const DEBUG_SPHERE = false;

// Dome profile as a superellipse, parameterised so sampling stays smooth:
//   (rho/R)^n + (h/H)^n = 1   ->   rho = R cos^(2/n) a,  h = H sin^(2/n) a
const domeProfile = (t) => {
  const a = (t * Math.PI) / 2;
  const e = 2 / DOME_N;
  return {
    rho: R * Math.pow(Math.abs(Math.cos(a)), e),
    h: DOME_H * Math.pow(Math.abs(Math.sin(a)), e),
  };
};

// Meridian normal by central difference on the profile, rather than by hand.
// The profile can then be retuned by editing one function instead of redoing
// the calculus.
const domeNormal = (t) => {
  const e = 0.0015;
  const p0 = domeProfile(Math.max(0, t - e));
  const p1 = domeProfile(Math.min(1, t + e));
  const dr = p1.rho - p0.rho;
  const dh = p1.h - p0.h;
  const len = Math.hypot(dh, dr) || 1;
  return { nr: dh / len, ny: -dr / len }; // tangent rotated outward
};

function frame(angle) {
  const chars = new Array(COLS * ROWS).fill(" ");
  const zbuf = new Array(COLS * ROWS).fill(0);

  const cosA = Math.cos(angle), sinA = Math.sin(angle);
  const cosB = Math.cos(TILT), sinB = Math.sin(TILT);

  // px,py,pz = point; nx,ny,nz = unit normal; shade = 0..1 surface darkening
  const plot = (px, py, pz, nx, ny, nz, shade) => {
    // Spin about the vertical axis, then apply the fixed tilt. The normal gets
    // the same treatment or the lighting detaches from the geometry.
    const x = px * cosA + pz * sinA;
    const z = -px * sinA + pz * cosA;
    const y2 = py * cosB - z * sinB;
    const z2 = py * sinB + z * cosB;

    const mx = nx * cosA + nz * sinA;
    const mz = -nx * sinA + nz * cosA;
    const my2 = ny * cosB - mz * sinB;
    const mz2 = ny * sinB + mz * cosB;

    const L = mx * LX + my2 * LY + mz2 * LZ;
    if (L <= 0) return; // facing away from the light

    let lum = L * shade;
    if (lum < LUM_FLOOR) return; // keeps the rim crisp instead of hazy
    lum = Math.pow(lum, GAMMA);

    const ooz = 1 / (z2 + K2);
    const sx = Math.round(COLS / 2 + K1 * ooz * x);
    const sy = Math.round(ROWS / 2 - K1 * ooz * (y2 - Y_CENTRE) * ASPECT);
    if (sx < 0 || sx >= COLS || sy < 0 || sy >= ROWS) return;

    const i = sy * COLS + sx;
    if (ooz <= zbuf[i]) return; // something nearer already owns this cell
    zbuf[i] = ooz;

    const idx = Math.min(RAMP.length - 1, Math.max(0, Math.floor(lum * RAMP.length)));
    chars[i] = RAMP[idx];
  };

  // Sweep a horizontal ring, stepping theta so screen-space sample density
  // stays roughly constant from the wide drum to the narrow spire. A fixed
  // step leaves visible gaps wherever the radius is large.
  const ring = (radius, fn) => {
    const dth = BASE_DTH / Math.max(radius, 0.1);
    for (let th = 0; th < TAU; th += dth) fn(Math.cos(th), Math.sin(th), th);
  };

  if (DEBUG_SPHERE) {
    for (let phi = 0; phi <= Math.PI; phi += 0.03) {
      const sp = Math.sin(phi), cp = Math.cos(phi);
      ring(sp, (ct, st) => plot(sp * ct, cp, sp * st, sp * ct, cp, sp * st, 1));
    }
  } else {
    // ── Dome, with meridian ribs. Rib contrast fades toward the apex, where
    // the meridians converge and would otherwise turn into noise.
    for (let t = 0; t <= 1; t += 0.02) {
      const { rho, h } = domeProfile(t);
      const { nr, ny } = domeNormal(t);
      const ribAmt = 0.42 * (1 - 0.55 * t);
      // The overhanging cornice shadows the dome's springing. This is what
      // actually separates dome from drum: without it the dome's lowest rows
      // and the cornice light to the same value and the join disappears, no
      // matter how bright the cornice is made.
      const skirt = h < 0.12 ? 0.4 + 0.6 * (h / 0.12) : 1;
      ring(rho, (ct, st, th) => {
        const rib = Math.pow(Math.abs(Math.cos((RIBS * th) / 2)), 8);
        plot(rho * ct, h, rho * st, nr * ct, ny, nr * st, (1 - ribAmt * rib) * skirt);
      });
    }

    // ── Cornice: one bright band at the springing. This horizontal break is
    // what makes dome-on-drum parse as a building rather than as one blob.
    //
    // It was a torus, which is the honest shape and the wrong one here: the
    // tube's overhang projected stray marks several cells clear of the
    // silhouette on both sides. A flat band is what the grid can hold.
    for (let y = -0.09; y < 0.105; y += 0.014) {
      ring(1.13, (ct, st) => plot(1.13 * ct, y, 1.13 * st, ct, 0, st, 1));
    }

    // ── Drum: one cylinder with vertical column bands.
    //
    // This was 16 modelled column cylinders in front of a recessed wall, which
    // is the physically right answer and completely wrong here: the drum spans
    // about 32 character cells, so each column landed on well under one cell
    // and the base rendered as noise. Bands read where geometry cannot.
    //
    // The downward falloff matters independently - the normal is (cos, 0, sin)
    // with no y term, so without it luminance depends only on theta, every row
    // of the drum renders the identical string, and it reads as repeated text
    // rather than as a lit cylinder.
    const ao = (y) => 0.76 + 0.24 * ((y + DRUM) / DRUM);
    for (let y = -DRUM; y < -0.03; y += 0.022) {
      ring(0.96, (ct, st, th) => {
        const band = Math.pow(Math.abs(Math.cos((COLUMNS * th) / 2)), 5);
        plot(0.96 * ct, y, 0.96 * st, ct, 0, st, (0.34 + 0.66 * band) * ao(y));
      });
    }

    // ── Base band, closing the drum.
    for (let y = -DRUM - 0.075; y < -DRUM + 0.01; y += 0.016) {
      ring(1.06, (ct, st) => plot(1.06 * ct, y, 1.06 * st, ct, 0, st, 0.95));
    }

    // ── Lantern: a small drum with a ring above and below it.
    for (let y = LANTERN_Y; y < LANTERN_Y + 0.20; y += 0.024) {
      ring(0.19, (ct, st) => plot(0.19 * ct, y, 0.19 * st, ct, 0, st, 0.95));
    }
    for (const yy of [LANTERN_Y, LANTERN_Y + 0.20]) {
      for (let u = 0; u < TAU; u += 0.45) {
        const cu = Math.cos(u), su = Math.sin(u);
        const rr = 0.23 + 0.032 * cu;
        ring(rr, (ct, st) => plot(rr * ct, yy + 0.03 * su, rr * st, cu * ct, su, cu * st, 1));
      }
    }

    // ── Spire, tapering into the statue.
    const SP0 = LANTERN_Y + 0.24, SP1 = LANTERN_Y + 0.54;
    for (let y = SP0; y < SP1; y += 0.018) {
      const rad = 0.13 * (1 - (y - SP0) / (SP1 - SP0)) + 0.02;
      ring(rad, (ct, st) => plot(rad * ct, y, rad * st, ct, 0, st, 1));
    }

    // ── The statue on top.
    const STATUE = 0.085;
    const SY = SP1 + STATUE;
    for (let phi = 0; phi <= Math.PI; phi += 0.1) {
      const sp = Math.sin(phi), cp = Math.cos(phi);
      ring(Math.max(sp * STATUE, 0.02), (ct, st) =>
        plot(STATUE * sp * ct, SY + STATUE * cp, STATUE * sp * st, sp * ct, cp, sp * st, 1)
      );
    }
  }

  let out = "";
  for (let r = 0; r < ROWS; r++) out += chars.slice(r * COLS, (r + 1) * COLS).join("") + "\n";
  return out;
}

// ── Frame loop ──────────────────────────────────────────────────────
// Module scope, so a re-bundle replaces the timer instead of stacking a second
// one on top of it. The element is looked up every tick rather than captured,
// which means the loop survives Ubersicht replacing the node on refresh.
const ELEMENT_ID = "nd-golden-dome";
const FPS = 15;
const SPIN = 0.035; // rad/frame -> about 12s per revolution

if (typeof window !== "undefined") {
  if (window.__ndDomeTimer) clearInterval(window.__ndDomeTimer);
  let angle = 0;
  window.__ndDomeTimer = setInterval(() => {
    const el = document.getElementById(ELEMENT_ID);
    if (!el) return;
    angle = (angle + SPIN) % TAU;
    el.textContent = frame(angle);
  }, 1000 / FPS);
}

export const className = `
  right: 24px;
  top: 300px;
  width: 320px;
  ${card(tn.yellow, "600ms")}

  .dome {
    margin: 2px 0 0;
    font-family: ${FONT};
    font-size: ${FONT_PX}px;
    line-height: ${LINE_PX}px;
    letter-spacing: 0;
    white-space: pre;
    text-align: center;

    /* Metallic sweep clipped to the glyphs - the one thing that actually makes
       it read as gold rather than as yellow text. */
    background: linear-gradient(
      170deg,
      ${tn.yellow} 0%,
      #ffd995 28%,
      ${tn.orange} 55%,
      ${tn.yellow} 100%
    );
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    filter: drop-shadow(0 0 6px rgba(224, 175, 104, 0.28));
  }

  .sig {
    margin-top: 6px;
    text-align: center;
    font-size: 9px;
    letter-spacing: 0.28em;
    color: ${tn.comment};
  }
`;

export const render = () => (
  <div>
    <h1>Golden Dome</h1>
    <pre className="dome" id={ELEMENT_ID} />
    <div className="sig">NOTRE DAME DU LAC</div>
  </div>
);
