// ============================================================
//  DUSKBLADE — tunable parameters
// ============================================================
#define ITER          5      // fbm octaves: detail vs. cost
#define SCENE_SCALE    3.0    // domain zoom of the smoke field
#define SPEED          1.0    // global motion multiplier (subtle when ~1)

// --- Energy core ---
const vec3  CORE_COLOR   = vec3(0.95, 0.10, 0.12); // bright crimson
const vec3  CORE_DEEP    = vec3(0.22, 0.02, 0.04); // deep shadow red
#define CORE_RADIUS    0.55   // falloff radius of the volumetric glow
#define CORE_SOFTNESS  1.8    // falloff exponent (higher = tighter core)
#define CORE_INTENSITY 1.35   // glow gain

// --- Smoke field ---
const vec3  SMOKE_COLOR  = vec3(0.10, 0.03, 0.14); // dark purple
const vec3  SMOKE_DEEP   = vec3(0.01, 0.00, 0.01); // near-black
#define WARP_STRENGTH  3.6    // domain-warp feedback gain (swirl amount)

// --- Post ---
#define VIGNETTE       1.25   // vignette strength (edge darkening)
#define GRAIN          0.06   // film grain amount
#define BRIGHTNESS     1.15   // exposure
#define GAMMA          0.90   // gamma correction (output = pow(col, 1/GAMMA))

// ============================================================
//  Helper functions: hash -> noise -> fbm
// ============================================================

// Deterministic 2D hash -> [0,1)
float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Value noise, smoothstep-interpolated -> [0,1]
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

// Fractal Brownian motion: ITER octaves, amplitude halving,
// fixed inter-octave rotation to break up axis-aligned artifacts.
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    float f = 1.0;
    mat2 rot = mat2(0.877, 0.479, -0.479, 0.877);

    for (int i = 0; i < ITER; i++) {
        v += a * noise(p * f);
        f *= 2.0;
        a *= 0.5;
        p *= rot;
    }
    return v;
}

// ============================================================
//  Smoke field: two-stage domain-warped fbm -> scene(p, t)
//  Time enters as slow additive drift (coeffs <= 0.04) so the
//  fog swirls continuously and subtly with no abrupt pulsing.
// ============================================================
float scene(vec2 p, float t) {
    t *= SPEED;
    vec2 q = vec2(fbm(p + vec2(0.0, t * 0.03)),
                  fbm(p + vec2(t * 0.04, 3.7)));
    vec2 r = vec2(fbm(p + WARP_STRENGTH * q + vec2(1.9, 8.2) + t * 0.025),
                  fbm(p + WARP_STRENGTH * q + vec2(7.3, 2.1) + t * 0.030));
    return fbm(p + (WARP_STRENGTH + 0.6) * r);
}

// ============================================================
//  Radial energy field: volumetric crimson core -> energyField(r, t, n)
//  Smooth radial falloff peaking at r=0 and monotonically
//  decreasing in r, softly modulated by the smoke field n so the
//  glow reads as volumetric rather than a flat gradient. The
//  breakup factor is bounded to [0.85, 1.0] so it can never
//  introduce abrupt brightness pulses.
// ============================================================
float energyField(float r, float t, float n) {
    // Smooth radial core, max at r=0, monotonically decreasing in r.
    float core = pow(clamp(1.0 - r / CORE_RADIUS, 0.0, 1.0), CORE_SOFTNESS);
    // Subtle volumetric breakup from the noise base (kept gentle, no pulse).
    float breakup = 0.85 + 0.15 * n;
    return clamp(core * breakup * CORE_INTENSITY, 0.0, 1.0);
}
// ============================================================
//  Entry point: mainImage
//  [1] Coordinate normalization, [2] smoke substrate,
//  [3] radial energy field, [4] color composition,
//  [5] post stage (vignette/grain/brightness/gamma) + opaque write.
// ============================================================
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // [1] Coordinate normalization — aspect-correct, centered.
    // Dividing by min(res.x, res.y) maps the center to the origin
    // and keeps the core circular regardless of aspect ratio.
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / min(iResolution.x, iResolution.y);
    float r = length(uv);          // radial distance from center
    vec2  p = uv * SCENE_SCALE;     // domain coordinates for the noise field

    // [2] Smoke substrate + [3] radial energy field — animated by iTime.
    float n    = scene(p, iTime);
    float core = energyField(r, iTime, n);

    // [4] Color composition.
    // Smoke: dark purple in lit fog, near-black in voids; darkens toward edges.
    vec3 smoke = mix(SMOKE_DEEP, SMOKE_COLOR, n) * (1.0 - 0.6 * r);
    // Core: bright crimson at center, deep shadow red as it fades out.
    vec3 coreCol = mix(CORE_DEEP, CORE_COLOR, core);
    // Layer the core over the smoke by the energy weight for high
    // center-to-edge contrast.
    vec3 col = mix(smoke, coreCol, core);

    // [5] Post stage — runs after composition.
    // [5a] Vignette — darkens edges, factor in [0,1], max at center.
    float vig = clamp(1.0 - dot(uv, uv) * VIGNETTE, 0.0, 1.0);
    col *= vig;

    // [5b] Film grain — bounded per-pixel perturbation.
    float grain = hash(fragCoord + fract(iTime)) * GRAIN;
    col = mix(col, col + grain, 0.3);

    // [5c] Brightness + gamma — monotonic, maps black to black.
    col = pow(max(col, 0.0), vec3(1.0 / GAMMA)) * BRIGHTNESS;

    fragColor = vec4(col, 1.0);   // opaque
}
