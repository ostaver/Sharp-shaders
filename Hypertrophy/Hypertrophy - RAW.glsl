const float u_baseH = 210.0;

const vec3 backgroundColor = vec3(8.0 / 255.0, 6.0 / 255.0, 12.0 / 255.0);

float hash(vec2 p) { 
    float h = dot(p, vec2(127.1, 311.7)); 
    return fract(sin(h) * 43758.5453123); 
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for(int i = 0; i < 10; ++i) { 
        v += a * noise(p); 
        p = rot * p * 2.0 + shift; 
        a *= 0.5; 
    }
    return v;
}

// Smooth wave-based domain warping
float waveField(vec2 p, float t) {
    float d1 = sin(p.x * 0.8 + t) * cos(p.y * 0.6 + t * 1.3) * 1.5;
    float d2 = sin(p.y * 0.7 + t * 0.8) * cos(p.x * 0.9 - t * 1.1) * 1.5;
    float d3 = sin((p.x + p.y) * 0.5 + t * 0.6) * cos((p.x - p.y) * 0.6 + t * 0.9) * 1.2;
    return (d1 + d2 + d3) / 4.2;
}

vec3 hsl2rgb(vec3 hsl) {
    vec3 rgb = clamp(abs(mod(hsl.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return hsl.z + hsl.y * (rgb - 0.5) * (1.0 - abs(2.0 * hsl.z - 1.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    // Keep centered and maintain aspect ratio
    vec2 st = vec2(uv.x * (iResolution.x / iResolution.y), uv.y) * 2.5;
    
    // Slow, gentle time
    float t = iTime * 0.16;
    
    // Domain warping - displace coordinates smoothly
    vec2 warp1 = vec2(
        waveField(st + vec2(0.0, 0.3), t),
        waveField(st + vec2(1.7, 0.8), t + 1.0)
    );
    
    vec2 warp2 = vec2(
        waveField(st + 2.0 * warp1 + vec2(0.5, 1.2), t * 0.7),
        waveField(st + 2.0 * warp1 + vec2(2.1, 0.4), t * 0.7 + 0.5)
    );
    
    // Final pattern uses FBM on warped coordinates for smooth detail
    float f = fbm(st + 1.8 * warp2);
    
    // Secondary layer for subtle color variation
    vec2 warp3 = vec2(
        waveField(st + 1.5 * warp2 + vec2(3.1, 1.5), t * 0.5 + 2.0),
        waveField(st + 1.5 * warp2 + vec2(0.8, 2.7), t * 0.5 + 2.5)
    );
    float f2 = fbm(st + 2.0 * warp3);
    
    // Smooth, elegant color
    float hueShift = (f - 0.5) * 12.0 + (f2 - 0.5) * 4.0;
    float hue = u_baseH + hueShift;
    hue = mod(hue, 360.0) / 360.0;
    
    float sat = mix(0.35, 0.7, smoothstep(0.3, 0.7, f * 1.1));
    float light = mix(0.04, 0.22, smoothstep(0.2, 0.7, f * f * 1.3));
    
    vec3 color = hsl2rgb(vec3(hue, sat, light));
    
    // Gentle glow on brighter areas
    float glow = smoothstep(0.55, 0.75, f) * 0.15;
    color += glow * vec3(0.6, 0.75, 1.0);
    
    // Soft vignette
    float vig = 1.0 - length(uv - 0.5) * 1.1;
    vig = smoothstep(0.0, 1.0, vig);
    color *= mix(0.75, 1.05, vig);
    
    // Smooth alpha with more range
    float alpha = smoothstep(0.08, 0.35, f) * 0.65 + 0.06;
    
    // Subtle shimmer
    float shimmer = smoothstep(0.6, 0.8, f) * smoothstep(0.6, 0.8, f2) * 0.12;
    color += shimmer * vec3(0.8, 0.85, 1.0);
    
    vec3 finalColor = mix(backgroundColor, color, alpha);
    
    fragColor = vec4(finalColor, 1.0);
}