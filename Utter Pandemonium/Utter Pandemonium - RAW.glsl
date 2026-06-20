#define PI 3.14159265

// ===================== PARAMETERS ===========================
// Detail / performance
const int   DETAIL       = 64;     // raymarch steps (higher = crisper, heavier)
const float MAX_DIST     = 32.0;   // far clip distance for the march

// Iridescent palette  ->  col = A + B * cos(2pi * (C * t + D))
const vec3  PAL_A        = vec3(0.50, 0.50, 0.50);
const vec3  PAL_B        = vec3(0.50, 0.50, 0.50);
const vec3  PAL_C        = vec3(1.00, 1.00, 1.00);
const vec3  PAL_D        = vec3(0.10, 0.40, 0.55);

// Lattice geometry
const float CELL_SIZE    = 1.2;    // spacing between grid lines
const float TWIST_DEPTH  = 0.14;   // spiral twist amount along depth (Z)
const float TWIST_TIME   = 0.2;   // animation speed of the twist
const float TWIST_VERT   = 0.06;   // secondary twist along height (Y)
const float SMOOTH_K     = 0.35;   // joint blending / anti-alias strength

// Glow & shading
const float GLOW_STR     = 0.016;  // overall glow intensity at line cores
const float GLOW_TIGHT   = 0.006;  // core tightness (smaller = sharper)
const float AA_NEAR      = 0.45;   // line softness up close
const float AA_FAR       = 0.06;   // extra softness added per unit depth
const float FADE_DENSITY = 0.075;  // atmospheric depth fade
const float LATTICE_GAIN = 0.055;  // master brightness of the lattice

// Foreground ribbons
const float RIBBON_COUNT = 8.0;    // number of energy streamers
const float RIBBON_CORE  = 0.010;  // ribbon thickness (smaller = thinner)
const float RIBBON_GAIN  = 0.15;   // master brightness of the ribbons

// Camera
const float CAM_SPEED    = 0.85;   // forward flight speed (can be negative)

// Post processing
const float EXPOSURE     = 1.35;   // tone-map exposure
const float SATURATION   = 1.20;   // color saturation lift
const float VIGNETTE     = 0.35;   // edge darkening strength
const float GRAIN_AMT    = 0.018;  // film grain amount
const float GAMMA        = 0.4545; // output gamma (~1/2.2)
// ============================================================

// ---- Iridescent cosine palette (the soul of the piece) -----
vec3 palette(in float t) {
    return PAL_A + PAL_B * cos(2.0 * PI * (PAL_C * t + PAL_D));
}

// ---- Helpers ------------------------------------------------
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

// Smooth minimum: blends shapes without sharp creases (anti-aliases joints)
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// ---- The lattice: distance to an infinite skeleton of lines -
// Domain repetition builds an endless 3D grid; a depth-driven
// twist makes it breathe and spiral like a living corridor.
float lattice(vec3 p) {
    p.xy *= rot(p.z * TWIST_DEPTH + iTime * TWIST_TIME);
    p.xz *= rot(p.y * TWIST_VERT);

    vec3 q = mod(p + CELL_SIZE * 0.5, CELL_SIZE) - CELL_SIZE * 0.5;

    // Distance to the three axis-aligned line bundles, blended smoothly
    float dx = length(q.yz);
    float dy = length(q.xz);
    float dz = length(q.xy);
    return smin(dx, smin(dy, dz, SMOOTH_K), SMOOTH_K);
}

// ---- Volumetric glow march through the lattice --------------
vec3 marchLattice(vec3 ro, vec3 rd, float dither) {
    vec3 col = vec3(0.0);

    // Stable per-pixel dither on the start point erases march banding
    float t = 0.15 + dither * 0.35;

    for (int i = 0; i < DETAIL; i++) {
        vec3 p = ro + rd * t;
        float d = lattice(p);

        // Distance-aware core width: far lines glow wider so they never
        // sub-pixel flicker (a cheap mip-map for buttery line edges)
        float aa = AA_NEAR + AA_FAR * t;
        float dd = d / aa;
        float g = GLOW_STR / (GLOW_TIGHT + dd * dd);

        // Iridescence shifts with depth, position and time
        float tone = 0.14 * t + 0.18 * p.z + 0.12 * sin(p.x * 0.4 + p.y * 0.3) + 0.08 * iTime;
        vec3 c = palette(tone);

        // Atmospheric depth fade
        float fade = exp(-t * FADE_DENSITY);

        col += c * g * fade;

        // Adaptive stepping: small near lines, large in the void
        t += clamp(d * 0.6, 0.035, 1.4);
        if (t > MAX_DIST) break;
    }

    return col * LATTICE_GAIN;
}

// ---- Foreground energy ribbons (the original sine-waves,
//      reimagined as soft volumetric streamers) --------------
vec3 ribbons(vec2 uv) {
    vec3 col = vec3(0.0);

    for (float i = 0.0; i < RIBBON_COUNT; i++) {
        float fi = i / RIBBON_COUNT;

        float amp   = 0.32 * (0.5 + 0.5 * sin(iTime * 0.7 + i * 1.7)) * (1.0 - 0.4 * fi);
        float freq  = 1.4 + i * 0.55;
        float phase = iTime * (0.30 + 0.16 * i);

        // Vertical offset spreads the ribbons across the frame
        float y = uv.y + amp * sin(freq * uv.x + phase) + (fi - 0.5) * 0.7;

        // Soft neon core — no hard edges, pure glow
        float glow = RIBBON_CORE / (RIBBON_CORE + y * y);

        vec3 c = palette(0.45 * uv.x + fi - 0.20 * iTime);

        // Taper the ends so ribbons feel like they recede in depth
        float taper = smoothstep(1.7, 0.4, abs(uv.x));
        col += c * glow * taper;
    }

    return col * RIBBON_GAIN;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
    float tt = iTime;

    // ---- Camera: gliding forward with a gentle drift & roll ----
    vec3 ro = vec3(0.0, 0.0, tt * CAM_SPEED);
    ro.xy += 0.30 * vec2(sin(tt * 0.31), cos(tt * 0.24));

    vec3 fwd   = normalize(vec3(0.10 * sin(tt * 0.20), 0.10 * cos(tt * 0.17), 1.0));
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
    vec3 up    = cross(fwd, right);

    float roll = 0.20 * sin(tt * 0.13);
    vec2 ruv = uv * rot(roll);
    vec3 rd = normalize(ruv.x * right + ruv.y * up + 1.45 * fwd);

    // ---- Compose the world ----
    // Stable spatial dither (no time term) breaks banding without flicker
    float dither = hash21(fragCoord);
    vec3 col = marchLattice(ro, rd, dither);
    col += ribbons(uv);

    // ---- Post processing ----
    // Filmic-ish tone map to tame the bright neon cores
    col = vec3(1.0) - exp(-col * EXPOSURE);

    // Subtle saturation lift for richer iridescence
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma), col, SATURATION);

    // Vignette
    float vig = 1.0 - VIGNETTE * dot(uv * 0.62, uv * 0.62);
    col *= clamp(vig, 0.0, 1.0);

    // Fine film grain (kept low so motion stays silky)
    float grain = hash21(fragCoord + fract(tt) * 311.7) - 0.5;
    col += grain * GRAIN_AMT;

    // Gamma correction
    col = pow(max(col, 0.0), vec3(GAMMA));

    fragColor = vec4(col, 1.0);
}
