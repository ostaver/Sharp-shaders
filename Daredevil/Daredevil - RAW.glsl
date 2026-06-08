#define ITER 4 //Detail, higher number = better but harder to load
#define SPEED 4.0 //Speed
#define GRAIN 0.08  // Grain/Noise filter
#define BRIGHTNESS 1.4 //Exposure

float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

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

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    float f = 1.0;
    mat2 rot = mat2(0.877, 0.479, -0.479, 0.877);
    
    for(int i = 0; i < ITER; i++) {
        v += a * noise(p * f);
        f *= 2.0;
        a *= 0.5;
        p *= rot;
    }
    return v;
}

float scene(vec2 p, float t) {
    t *= SPEED;
    
    float t1 = t * 0.03;
    float t2 = t * 0.04;
    float t3 = t * 0.025;
    float t4 = t * 0.03;
    
    vec2 q = vec2(
        fbm(p + vec2(0.0, t1)),
        fbm(p + vec2(t2, 3.7))
    );
    
    vec2 r = vec2(
        fbm(p + 3.8 * q + vec2(1.9, 8.2) + t3),
        fbm(p + 3.8 * q + vec2(7.3, 2.1) + t4)
    );
    
    return fbm(p + 4.2 * r);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / min(iResolution.x, iResolution.y);
    vec2 p = uv * 3.5;
    
    float n = scene(p, iTime);
    
    // Color
    float hue = fract(0.889 + n * 0.08);
    float sat = 0.35 + n * 0.35;
    float lum = 0.06 + n * 0.13;
    
    vec3 rgb = clamp(
        abs(mod(hue * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0,
        0.0, 1.0
    );
    vec3 col = lum + sat * (rgb - 0.5) * (1.0 - abs(2.0 * lum - 1.0));
    
    // Vignette
    vec2 vig_uv = fragCoord / iResolution.xy - 0.5;
    float vig = 1.0 - dot(vig_uv, vig_uv) * 1.5;
    col *= max(vig, 0.0);
    
    // VISIBLE GRAIN - using fragCoord directly for pixel-level noise
    // Method 1: Raw pixel noise
    float grain = hash(fragCoord) * GRAIN;
    
    // Method 2: Animated grain (comment out method 1 and uncomment this to test)
    // float grain = hash(fragCoord + vec2(iTime * 60.0, iTime * 40.0)) * GRAIN;
    
    // Mix grain with color (additive blend)
    col = mix(col, col + grain, 0.3);  // 30% blend
    
    // Or try overlay-style grain (more natural)
    // col = col + (grain - GRAIN * 0.5) * 0.3;
    
    fragColor = vec4(col, 1.0) * BRIGHTNESS;
}