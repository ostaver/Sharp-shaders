const float u_baseH = 200.0;
#define ITERATIONS 8 // Detail (higher is GPU heaver)

const vec3 backgroundColor = vec3(8.0 / 255.0, 5.0 / 255.0, 15.0 / 255.0); 

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
    for(int i = 0; i < ITERATIONS; ++i) { 
        v += a * noise(p); 
        p = rot * p * 2.0 + shift; 
        a *= 0.5; 
    }
    return v;
}

vec3 hsl2rgb(vec3 hsl) {
    vec3 rgb = clamp(abs(mod(hsl.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return hsl.z + hsl.y * (rgb - 0.5) * (1.0 - abs(2.0 * hsl.z - 1.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalized pixel coordinates
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    // Adjust aspect ratio and scale
    vec2 st = vec2(uv.x * (iResolution.x / iResolution.y), uv.y) * 2.5;
    
    // Enhanced fluid motion with more complex paths
    float timeSlow = iTime * 0.02;
    float timeMed = iTime * 0.035;
    float timeFast = iTime * 0.05;
    
    vec2 q1 = vec2(fbm(st + timeMed), fbm(st + vec2(5.2, 1.3) + timeFast));
    vec2 q2 = vec2(fbm(st + 3.0 * q1 + vec2(1.7, 9.2) + timeSlow), 
                   fbm(st + 3.0 * q1 + vec2(8.3, 2.8) + timeMed));
    
    // Additional detail layer for more complexity
    vec2 r = vec2(fbm(st + 4.0 * q2 + vec2(1.7, 9.2) + timeSlow * 0.7), 
                  fbm(st + 4.0 * q2 + vec2(8.3, 2.8) + timeMed * 0.8));
    
    float f = fbm(st + 4.0 * r);
    
    // Secondary value for color variation
    float f2 = fbm(st + 3.0 * r + vec2(3.3, 6.7));
    
    // Enhanced color generation with wider hue range
    float hueShift = (f - 0.5) * 24.0 + (f2 - 0.5) * 8.0;  // More hue variation
    float hue = u_baseH + hueShift;
    hue = mod(hue, 360.0) / 360.0;
    
    // Brighter, more saturated colors
    float sat = mix(0.4, 0.95, clamp(f * 1.4 + f2 * 0.3, 0.0, 1.0));  // Increased saturation
    float light = mix(0.05, 0.35, clamp(f * f * 2.0 + f2 * 0.4, 0.0, 1.0));  // Brighter highlights
    
    vec3 color = hsl2rgb(vec3(hue, sat, light));
    
    // Add subtle glow to bright areas
    float glow = clamp(f * 1.5 - 0.3, 0.0, 1.0) * 0.3;
    color += glow * vec3(0.7, 0.8, 1.0);  // Blue-ish glow
    
    // Enhanced vignette effect - softer falloff
    float vig = 1.0 - length(uv - 0.5) * 1.4;
    vig = smoothstep(0.0, 1.0, vig);
    color *= mix(0.8, 1.0, vig);  // Brighter center
    
    // Calculate alpha transparency with more range
    float alpha = smoothstep(0.05, 0.4, f) * 0.25 + 0.08;  // Slightly higher opacity
    
    // Add subtle sparkle to bright areas
    float sparkle = smoothstep(0.6, 0.8, f) * 0.2;
    color += sparkle * vec3(0.9, 0.95, 1.0);
    
    // Blend with background
    vec3 finalColor = mix(backgroundColor, color, alpha);
    
    // Subtle color boost in bright regions
    finalColor = mix(finalColor, finalColor * 1.2, alpha * 0.3);
    
    fragColor = vec4(finalColor, 1.0);
}