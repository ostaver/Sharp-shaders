#define FBM_OCTAVES 5

const float NOISE_SCALE          = 2.65;
const float RISE_SPEED           = 0.48;
const float WARP_STRENGTH        = 1.85;
const float EXPOSURE             = 1.25;
const float CHROMATIC_ABERRATION = 0.0035;
const float GRAIN_STRENGTH       = 0.018;

const mat2 NOISE_ROTATION = mat2(0.80, -0.60,
                                     0.60,  0.80);

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float valueNoise(vec2 p) {
    vec2 cell = floor(p);
    vec2 local = fract(p);

    // Quintic interpolation keeps octave derivatives visually smooth.
    local = local * local * local * (local * (local * 6.0 - 15.0) + 10.0);

    float a = hash21(cell);
    float b = hash21(cell + vec2(1.0, 0.0));
    float c = hash21(cell + vec2(0.0, 1.0));
    float d = hash21(cell + vec2(1.0, 1.0));

    return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float fbm(vec2 p) {
    float sum = 0.0;
    float amplitude = 0.52;

    for (int i = 0; i < FBM_OCTAVES; i++) {
        sum += amplitude * valueNoise(p);
        p = NOISE_ROTATION * p * 2.03 + vec2(17.13, 9.17);
        amplitude *= 0.5;
    }

    return sum;
}

// Two nested FBM vector fields fold the domain before the final sample.
// Time is fed into each stage at a different rate to avoid simple scrolling.
vec4 domainWarp(vec2 p, float time) {
    vec2 q = vec2(
        fbm(p + vec2(0.0, -time * 0.18)),
        fbm(p + vec2(5.2, 1.3) + vec2(time * 0.11, -time * 0.14))
    );

    vec2 r = vec2(
        fbm(p + WARP_STRENGTH * q + vec2(1.7, 9.2) + time * vec2(0.08, -0.12)),
        fbm(p + WARP_STRENGTH * q + vec2(8.3, 2.8) + time * vec2(-0.10, -0.09))
    );

    float detail = fbm(p + 2.35 * r + 0.35 * q);
    return vec4(detail, q.x, q.y, 0.5 * (r.x + r.y));
}

// Black -> crimson -> orange -> gold -> white-hot.
vec3 heatRamp(float temperature) {
    float t = clamp(temperature, 0.0, 1.0);
    vec3 color = mix(vec3(0.035, 0.002, 0.001),
                     vec3(0.42, 0.012, 0.002), smoothstep(0.00, 0.22, t));
    color = mix(color, vec3(1.00, 0.105, 0.006), smoothstep(0.18, 0.48, t));
    color = mix(color, vec3(1.00, 0.56, 0.035), smoothstep(0.42, 0.72, t));
    color = mix(color, vec3(1.00, 0.93, 0.58), smoothstep(0.68, 0.91, t));
    color = mix(color, vec3(1.00, 0.985, 0.92), smoothstep(0.88, 1.00, t));
    return color;
}

// Returns fire density, smoke density, temperature, and turbulence.
vec4 sampleMedium(vec2 uv) {
    float time = iTime;
    float height = uv.y + 0.58;

    // Large-scale buoyant sway bends more strongly toward the plume tip.
    float sway = 0.075 * sin(time * 0.83 + height * 3.2)
                + 0.035 * sin(time * 1.37 - height * 6.1);
    vec2 p = uv;
    p.x -= sway * smoothstep(0.05, 1.15, height);

    // Sampling a downward-moving field makes its features travel upward.
    vec2 noiseUv = vec2(p.x * 1.28, p.y * 0.88) * NOISE_SCALE;
    noiseUv.y -= time * RISE_SPEED;
    vec4 warped = domainWarp(noiseUv, time);

    float turbulence = clamp(0.62 * warped.x + 0.38 * warped.w, 0.0, 1.0);

    // A tapered envelope gives the noise a recognizable flame silhouette.
    float taper = smoothstep(0.0, 1.22, height);
    float width = mix(0.52, 0.075, taper);
    float side = abs(p.x) / max(width, 0.001);
    float body = 1.0 - side;

    // Break the upper core apart so it resolves into licking flame tongues.
    float split = smoothstep(0.48, 1.08, height)
                * exp(-22.0 * p.x * p.x)
                * (0.18 + 0.34 * warped.y);

    float raggedEdge = body + 1.08 * (turbulence - 0.48)
                     + 0.16 * (warped.z - 0.5) - split;
    float verticalMask = smoothstep(-0.03, 0.055, height)
                       * (1.0 - smoothstep(0.88, 1.25,
                                           height + 0.16 * (turbulence - 0.5)));
    float fire = smoothstep(0.04, 0.54, raggedEdge) * verticalMask;

    // Small turbulent voids stop the body from reading as a flat alpha shape.
    float breakup = smoothstep(0.20, 0.60,
                               turbulence + 0.24 * body - 0.08 * height);
    fire *= mix(0.42, 1.0, breakup);

    // Hotter near the lower center; cooler toward wispy edges and the tip.
    float core = exp(-4.8 * side * side)
               * (1.0 - smoothstep(0.42, 1.05, height));
    float temperature = clamp(0.12 + 0.50 * fire + 0.56 * core
                              - 0.17 * height + 0.12 * warped.y,
                              0.0, 1.0);

    // Smoke expands above the flame and shares its flow field for continuity.
    float smokeWidth = width + 0.12 + 0.22 * smoothstep(0.25, 1.1, height);
    float smokeEnvelope = 1.0 - smoothstep(0.42, 1.18,
                                           abs(p.x) / smokeWidth);
    float smokeTexture = 0.58 * warped.x + 0.42 * warped.w;
    float smoke = smoothstep(0.34, 0.72,
                             smokeTexture + 0.30 * smokeEnvelope)
                * smokeEnvelope
                * smoothstep(0.30, 0.78, height);
    smoke *= 1.0 - 0.70 * fire;

    return vec4(fire, smoke, temperature, turbulence);
}

vec3 renderScene(vec2 uv) {
    vec4 medium = sampleMedium(uv);
    float fire = medium.x;
    float smoke = medium.y;
    float temperature = medium.z;
    float turbulence = medium.w;
    float height = uv.y + 0.58;

    vec3 color = vec3(0.0015, 0.0020, 0.0035);

    // Cool soot receives a little warm scattered light near the flame.
    vec3 soot = mix(vec3(0.012, 0.014, 0.018),
                    vec3(0.115, 0.092, 0.074),
                    clamp(0.22 + 0.78 * turbulence, 0.0, 1.0));
    float smokeLight = 0.34 + 0.66 * exp(-2.3 * max(height - 0.35, 0.0));
    color += soot * smoke * smokeLight;

    // A broad, low-energy halo approximates light scattered through thin gas.
    float halo = exp(-3.3 * length(vec2(uv.x * 1.12, (height - 0.24) * 0.72)))
               * (0.55 + 0.45 * turbulence)
               * (1.0 - smoothstep(0.72, 1.35, height));
    color += vec3(0.19, 0.028, 0.0015) * halo;

    vec3 flameColor = heatRamp(temperature);
    color += flameColor * fire * (0.72 + 1.95 * temperature * temperature);

    // A reflected pool of orange light anchors the source below the frame.
    float baseGlow = exp(-5.0 * abs(uv.x))
                   * exp(-20.0 * abs(uv.y + 0.50));
    color += vec3(0.34, 0.045, 0.002) * baseGlow;

    return color;
}

vec3 renderEmbers(vec2 uv) {
    vec3 color = vec3(0.0);

    for (int i = 0; i < 12; i++) {
        float id = float(i);
        float speed = mix(0.10, 0.22, hash21(vec2(id, 2.7)));
        float life = fract(iTime * speed + hash21(vec2(id, 8.1)));

        float spread = mix(0.18, 0.54, life);
        float xSeed = hash21(vec2(id, 4.3)) - 0.5;
        float drift = 0.055 * sin(iTime * (0.8 + 0.07 * id) + id * 2.17);
        vec2 position = vec2(xSeed * spread + drift,
                             -0.48 + life * 1.20);

        vec2 delta = uv - position;
        float spark = exp(-1650.0 * dot(delta * vec2(1.0, 0.52),
                                       delta * vec2(1.0, 0.52)));
        spark *= (1.0 - smoothstep(0.72, 1.0, life)) * (1.0 - life);

        float flicker = 0.72 + 0.28 * sin(iTime * 13.0 + id * 5.7);
        color += mix(vec3(1.0, 0.16, 0.008),
                     vec3(1.0, 0.82, 0.30),
                     hash21(vec2(id, 6.4))) * spark * flicker;
    }

    return color * 2.4;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // Lens-like radial channel separation, strongest near the frame edge.
    float radius = length(uv);
    vec2 radial = uv / max(radius, 0.001);
    vec2 chromaOffset = radial * CHROMATIC_ABERRATION
                      * smoothstep(0.08, 0.95, radius);

    vec3 centerSample = renderScene(uv);
    vec3 redSample = renderScene(uv + chromaOffset);
    vec3 blueSample = renderScene(uv - chromaOffset);
    vec3 color = vec3(redSample.r, centerSample.g, blueSample.b);

    color += renderEmbers(uv);

    // Filmic ACES approximation preserves the white-hot center.
    color *= EXPOSURE;
    color = (color * (2.51 * color + 0.03))
          / (color * (2.43 * color + 0.59) + 0.14);

    float vignette = 1.0 - 0.32 * smoothstep(0.28, 1.15, dot(uv, uv));
    color *= vignette;

    // Frame-stepped grain avoids temporally crawling sub-pixel noise.
    float grain = hash21(fragCoord + floor(iTime * 24.0) * 19.17) - 0.5;
    color += grain * GRAIN_STRENGTH;

    color = pow(max(color, 0.0), vec3(0.4545));
    fragColor = vec4(color, 1.0);
}
