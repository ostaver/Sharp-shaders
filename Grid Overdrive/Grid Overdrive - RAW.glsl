// Grid Overdrive — warped arcade arena through an overdriven CRT
// Single-pass Shadertoy shader. No textures, buffers, or audio required.

#define PI  3.14159265359
#define TAU 6.28318530718

float sat(float x) { return clamp(x, 0.0, 1.0); }

mat2 rotate2D(float a)
{
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

float hash11(float p)
{
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash21(vec2 p)
{
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec2 hash22(vec2 p)
{
    float n = hash21(p);
    return vec2(n, hash21(p + n + 19.19));
}

float valueNoise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p)
{
    float sum = 0.0;
    float amp = 0.5;
    mat2 m = mat2(0.80, -0.60, 0.60, 0.80);

    for (int i = 0; i < 4; i++) {
        sum += amp * valueNoise(p);
        p = m * p * 2.03 + 11.7;
        amp *= 0.5;
    }
    return sum;
}

vec3 gamePalette(float t)
{
    return 0.52 + 0.48 * cos(TAU * (t + vec3(0.02, 0.34, 0.66)));
}

float sdSegment(vec2 p, vec2 a, vec2 b)
{
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = sat(dot(pa, ba) / dot(ba, ba));
    return length(pa - ba * h);
}

float sdBox(vec2 p, vec2 b)
{
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// A tiny procedural city at the horizon gives the grid a game-world scale.
vec3 skyline(vec2 p, float horizon, float t)
{
    float column = floor((p.x + 4.0) * 24.0);
    float seed = hash11(column);
    float widthMask = step(fract((p.x + 4.0) * 24.0), 0.68 + 0.24 * seed);
    float height = 0.025 + 0.105 * seed * seed;
    float building = step(horizon, p.y) * (1.0 - step(horizon + height, p.y)) * widthMask;

    vec3 col = mix(vec3(0.015, 0.025, 0.065), vec3(0.055, 0.025, 0.095), seed);
    float windowRow = step(0.78, hash21(vec2(column, floor((p.y - horizon) * 180.0))));
    float windows = building * windowRow * step(0.32, fract((p.x + 4.0) * 48.0));
    col *= building;
    col += gamePalette(seed + t * 0.01) * windows * 0.45;

    // Rooftop warning beacons blink out of phase.
    float roof = exp(-abs(p.y - horizon - height) * 500.0) * widthMask;
    float blink = pow(0.5 + 0.5 * sin(t * 3.0 + seed * TAU), 12.0);
    col += vec3(1.0, 0.04, 0.20) * roof * blink * step(0.82, seed);
    return col;
}

vec3 worldScene(vec2 p, float t)
{
    float horizon = 0.105 + 0.008 * sin(t * 0.37);
    float beat = pow(0.5 + 0.5 * sin(t * 2.15), 10.0);

    // Layered night sky and animated digital nebula.
    float skyMix = sat((p.y + 0.65) * 0.54);
    vec3 col = mix(vec3(0.008, 0.010, 0.040), vec3(0.045, 0.018, 0.100), skyMix);
    float cloud = fbm(p * vec2(1.8, 2.6) + vec2(t * 0.018, -t * 0.011));
    col += mix(vec3(0.015, 0.10, 0.16), vec3(0.19, 0.025, 0.20), cloud)
         * pow(cloud, 3.0) * 0.24 * smoothstep(horizon, horizon + 0.20, p.y);

    // Star cells include random sub-cell positions and cross-shaped flares.
    vec2 starGrid = p * vec2(20.0, 16.0);
    vec2 starID = floor(starGrid);
    vec2 starP = fract(starGrid) - 0.5 - (hash22(starID) - 0.5) * 0.70;
    float starSeed = hash21(starID + 7.1);
    float starCore = (1.0 - smoothstep(0.018, 0.080, length(starP))) * step(0.87, starSeed);
    float starFlare = 0.0025 / (abs(starP.x * starP.y) + 0.006);
    float twinkle = 0.55 + 0.45 * sin(t * (1.0 + starSeed * 2.0) + starSeed * 30.0);
    col += gamePalette(starSeed) * starCore * (0.45 + twinkle * 0.80)
         * smoothstep(horizon + 0.03, horizon + 0.13, p.y);
    col += vec3(0.18, 0.26, 0.42) * starFlare * starCore * 0.018;

    // Segmented energy sun with a pulsing corona.
    vec2 sunCenter = vec2(-0.43 + 0.018 * sin(t * 0.16), 0.38);
    vec2 sunP = p - sunCenter;
    float sunD = length(sunP);
    float sunDisc = 1.0 - smoothstep(0.135, 0.143, sunD);
    float sunBands = smoothstep(0.12, 0.30, fract((sunP.y + t * 0.018) * 22.0));
    vec3 sunColor = mix(vec3(1.15, 0.18, 0.62), vec3(1.10, 0.72, 0.16),
                        sat((sunP.y + 0.14) * 3.5));
    col += sunColor * sunDisc * sunBands * (0.72 + 0.22 * beat);
    col += mix(vec3(0.15, 0.02, 0.32), vec3(0.75, 0.08, 0.42), beat)
         * exp(-sunD * 8.0) * 0.42;
    col += gamePalette(t * 0.025) * exp(-abs(sunD - 0.158) * 115.0) * 0.30;

    // High-altitude laser traffic.
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float laserY = 0.54 + fi * 0.13 + 0.03 * sin(t * (0.27 + fi * 0.05) + fi);
        float laser = 0.0016 / (abs(p.y - laserY - p.x * (0.035 - fi * 0.018)) + 0.004);
        float segment = smoothstep(0.05, 0.18, fract(p.x * 1.6 - t * (0.11 + fi * 0.03) + fi * 0.31));
        col += gamePalette(fi * 0.29 + t * 0.015) * laser * segment * 0.12;
    }

    col += skyline(p, horizon, t);

    // Ray/ground-plane intersection creates a real perspective grid.
    vec3 rayOrigin = vec3(0.0, 0.64, -1.45);
    vec3 rayDir = normalize(vec3(p.x, p.y - horizon, 1.22));

    if (rayDir.y < -0.001) {
        float rayDistance = -rayOrigin.y / rayDir.y;
        vec3 hit = rayOrigin + rayDir * rayDistance;
        hit.z += t * 2.65;

        // Multiple waves bend the entire playfield like a corrupted cartridge.
        float bend = 0.48 * sin(hit.z * 0.075 + t * 0.19)
                   + 0.17 * sin(hit.z * 0.23 - t * 0.41);
        hit.x += bend;
        hit.x += 0.075 * sin(hit.x * 2.2 + hit.z * 0.11 + t);

        float distanceFade = exp(-rayDistance * 0.031);
        float horizonFade = 1.0 - exp(-rayDistance * 0.13);

        // Minor and major lattice lines use distance-aware widths.
        vec2 minorCell = abs(fract(hit.xz / vec2(0.56, 0.90) + 0.5) - 0.5);
        vec2 majorCell = abs(fract(hit.xz / vec2(2.80, 4.50) + 0.5) - 0.5);
        float minorWidth = 0.018 + rayDistance * 0.0015;
        float majorWidth = 0.010 + rayDistance * 0.0008;
        float minorGrid = 1.0 - smoothstep(minorWidth, minorWidth * 2.2,
                                           min(minorCell.x, minorCell.y));
        float majorGrid = 1.0 - smoothstep(majorWidth, majorWidth * 2.6,
                                           min(majorCell.x, majorCell.y));

        float energyWave = 0.5 + 0.5 * sin(hit.z * 0.18 - t * 4.2);
        vec3 gridColor = mix(vec3(0.00, 0.54, 1.15), vec3(1.12, 0.02, 0.72),
                             sat(0.5 + hit.x * 0.10 + energyWave * 0.24));
        vec3 floorColor = mix(vec3(0.008, 0.012, 0.035), vec3(0.025, 0.008, 0.055),
                              sat(abs(hit.x) * 0.18));
        floorColor += gridColor * minorGrid * 0.34;
        floorColor += mix(gridColor, vec3(0.80, 0.92, 1.20), 0.38) * majorGrid * 0.72;

        // Racing lanes and center dashes stream toward the camera.
        float laneDistance = min(abs(hit.x - 1.18), abs(hit.x + 1.18));
        float lane = exp(-laneDistance * (20.0 - min(rayDistance, 10.0)));
        float lanePulse = 0.45 + 0.55 * sin(hit.z * 0.55 - t * 6.0);
        floorColor += mix(vec3(0.08, 0.72, 1.15), vec3(1.10, 0.06, 0.55), step(0.0, hit.x))
                    * lane * (0.22 + 0.32 * lanePulse);

        float centerLine = exp(-abs(hit.x) * 24.0);
        float centerDash = smoothstep(0.10, 0.18, fract(hit.z * 0.20));
        floorColor += vec3(0.92, 0.98, 1.12) * centerLine * centerDash * 0.50;

        // Random speed pickups flicker in world-space grid cells.
        vec2 pickupID = floor(hit.xz * vec2(1.3, 0.28));
        vec2 pickupP = fract(hit.xz * vec2(1.3, 0.28)) - 0.5;
        float pickupSeed = hash21(pickupID);
        float pickupShape = (1.0 - smoothstep(0.025, 0.090, length(pickupP)))
                          * step(0.91, pickupSeed);
        floorColor += gamePalette(pickupSeed + t * 0.06) * pickupShape * 1.4;

        // Expanding checkpoint rings travel beneath the viewer.
        float ringPhase = abs(fract((hit.z - t * 7.0) * 0.055) - 0.5);
        float checkpoint = 1.0 - smoothstep(0.015, 0.045, ringPhase);
        checkpoint *= exp(-abs(abs(hit.x) - 1.75) * 2.3);
        floorColor += vec3(0.18, 0.85, 1.25) * checkpoint * 0.48;

        floorColor *= distanceFade;
        floorColor += vec3(0.18, 0.025, 0.34) * horizonFade * exp(-rayDistance * 0.018) * 0.16;
        col = mix(col, floorColor, sat(-rayDir.y * 90.0));
    }

    // Horizon flare hides distant aliasing and sells the luminous arena fog.
    float horizonGlow = 0.010 / (abs(p.y - horizon) + 0.018);
    col += mix(vec3(0.08, 0.48, 1.10), vec3(1.00, 0.04, 0.58), 0.5 + 0.5 * sin(t * 0.31))
         * horizonGlow * (0.23 + 0.10 * beat);

    return col;
}

vec3 addGameHUD(vec3 col, vec2 p, float t)
{
    float beat = pow(0.5 + 0.5 * sin(t * 2.15), 10.0);
    vec2 target = vec2(0.20 * sin(t * 0.37), 0.13 + 0.09 * cos(t * 0.29));
    vec2 q = p - target;
    float angle = atan(q.y, q.x);

    float ring = exp(-abs(length(q) - 0.105) * 240.0);
    float segmented = step(0.42, fract(angle / TAU * 12.0 + t * 0.08));
    float cross = exp(-abs(q.x) * 230.0) * step(0.12, abs(q.y)) * (1.0 - step(0.19, abs(q.y)));
    cross += exp(-abs(q.y) * 230.0) * step(0.12, abs(q.x)) * (1.0 - step(0.19, abs(q.x)));
    vec3 hudColor = mix(vec3(0.05, 0.88, 1.20), vec3(1.20, 0.08, 0.60), beat);
    col += hudColor * (ring * segmented + cross) * 0.42;

    // Four corner brackets frame the active play area.
    vec2 a = abs(p) - vec2(0.73, 0.66);
    float cornerH = exp(-abs(a.y) * 300.0) * (1.0 - smoothstep(0.0, 0.105, abs(a.x)));
    float cornerV = exp(-abs(a.x) * 300.0) * (1.0 - smoothstep(0.0, 0.075, abs(a.y)));
    col += vec3(0.08, 0.62, 0.90) * (cornerH + cornerV) * 0.22;

    // Abstract status bars evoke a racing HUD without relying on text/fonts.
    vec2 panelP = p - vec2(0.53, 0.72);
    float panel = 1.0 - smoothstep(0.0, 0.008, abs(sdBox(panelP, vec2(0.17, 0.045))));
    col += vec3(0.10, 0.50, 0.74) * panel * 0.20;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        vec2 barP = panelP - vec2(-0.12 + fi * 0.055, 0.0);
        float bar = 1.0 - smoothstep(0.0, 0.006,
            sdBox(barP, vec2(0.020, 0.013 + 0.013 * sin(t * 1.7 + fi))));
        col += gamePalette(fi * 0.12 + t * 0.02) * bar * (0.28 + 0.16 * beat);
    }

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 resolution = iResolution.xy;
    vec2 screenUV = fragCoord / resolution;
    vec2 screen = screenUV * 2.0 - 1.0;
    screen.x *= resolution.x / resolution.y;

    // Persistent mouse position nudges the camera; idle drift works untouched.
    vec2 idleLook = 0.018 * vec2(sin(iTime * 0.23), cos(iTime * 0.19));
    vec2 mouseLook = (iMouse.xy - 0.5 * resolution) / resolution.y;
    float hasMouse = step(0.001, dot(iMouse.xy, iMouse.xy));
    vec2 look = mix(idleLook, mouseLook * 0.11, hasMouse);

    // Horizontal row glitches happen before scene sampling so the world tears.
    float row = floor(screenUV.y * 110.0);
    float glitchSeed = hash21(vec2(row, floor(iTime * 8.0)));
    float glitchGate = step(0.965, glitchSeed) * step(0.55, sin(iTime * 0.73) * 0.5 + 0.5);

    // Barrel distortion curves both geometry and scanout like a convex CRT.
    float radial = dot(screen, screen);
    vec2 curved = screen * (1.0 + 0.060 * radial + 0.012 * radial * radial);
    curved += look;
    curved.x += (glitchSeed - 0.5) * 0.075 * glitchGate;

    // RGB channels look through slightly different points in the curved glass.
    vec2 radialDir = normalize(curved + vec2(1e-5, 0.0));
    float edgeAberration = 0.0022 + radial * 0.0048 + glitchGate * 0.012;
    vec2 chroma = radialDir * edgeAberration;
    vec3 sceneR = worldScene(curved + chroma, iTime);
    vec3 sceneG = worldScene(curved, iTime);
    vec3 sceneB = worldScene(curved - chroma, iTime);
    vec3 col = vec3(sceneR.r, sceneG.g, sceneB.b);

    // Additive channel ghosts bloom around intense shapes during signal stress.
    col += vec3(sceneB.r, sceneR.g, sceneG.b) * (0.025 + glitchGate * 0.070);
    col = addGameHUD(col, curved, iTime);

    // Fine horizontal scanlines plus a slower rolling sync band.
    float scanline = 0.78 + 0.22 * sin(fragCoord.y * PI);
    float fineScan = 0.94 + 0.06 * sin(fragCoord.y * 0.36 - iTime * 8.0);
    float rollPosition = fract(screenUV.y - iTime * 0.085);
    float rollBand = exp(-abs(rollPosition - 0.5) * 18.0);
    col *= scanline * fineScan;
    col *= 0.94 + 0.10 * rollBand;

    // Triad phosphor mask: each pixel column favors a different color gun.
    float phosphor = mod(floor(fragCoord.x), 3.0);
    vec3 maskR = vec3(1.08, 0.86, 0.86);
    vec3 maskG = vec3(0.86, 1.08, 0.86);
    vec3 maskB = vec3(0.86, 0.86, 1.08);
    vec3 phosphorMask = mix(maskR, maskG, step(0.5, phosphor));
    phosphorMask = mix(phosphorMask, maskB, step(1.5, phosphor));
    col *= phosphorMask;

    // Analog snow, a faint vertical seam, and intermittent white tear lines.
    float noise = hash21(fragCoord + vec2(fract(iTime * 60.0) * 713.0, iTime));
    col += (noise - 0.5) * 0.028;
    float seam = exp(-abs(screenUV.x - fract(iTime * 0.017)) * 420.0);
    col += vec3(0.04, 0.10, 0.14) * seam;
    float tear = exp(-abs(fract(screenUV.y * 3.0 - iTime * 0.27) - 0.5) * 260.0) * glitchGate;
    col += vec3(0.48, 0.68, 0.76) * tear;

    // Rounded CRT glass, dark bezel, edge reflections, and bloom tonemapping.
    vec2 bezelP = vec2(abs(screen.x) / (resolution.x / resolution.y), abs(screen.y));
    float edge = max(bezelP.x, bezelP.y);
    float screenMask = 1.0 - smoothstep(0.945, 1.015, edge);
    float glassEdge = exp(-abs(edge - 0.965) * 90.0);
    col += vec3(0.12, 0.20, 0.28) * glassEdge * 0.20;
    col *= screenMask;

    float vignette = sat(1.10 - 0.48 * dot(screenUV - 0.5, screenUV - 0.5) * 4.0);
    col *= vignette;
    col = 1.0 - exp(-max(col, 0.0) * 1.12);
    col = pow(col, vec3(0.4545));

    fragColor = vec4(col, 1.0);
}
