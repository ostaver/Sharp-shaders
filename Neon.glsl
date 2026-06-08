// GLSL Neon project, language similar to C
// ─────────────────────────────────────────────────────────────
//  NEON — flowing neon tubes over a detailed procedural field.
//  Background: domain-warped fBm noise (no grid/blocks).
//  Shadertoy format: mainImage( out fragColor, in fragCoord )
// ─────────────────────────────────────────────────────────────

// Iridescent neon palette (cosine gradient, Inigo Quilez technique).
// Cheap, smooth, and loops naturally over t.
vec3 neonPalette( float t ) {
    vec3 a = vec3( 0.55, 0.40, 0.55 );
    vec3 b = vec3( 0.45, 0.45, 0.55 );
    vec3 c = vec3( 1.00, 1.00, 1.00 );
    vec3 d = vec3( 0.00, 0.33, 0.67 );
    return a + b * cos( 6.2831853 * ( c * t + d ) );
}

// Glow of a single horizontal neon tube positioned at wave(x).
// Returns an intensity that spikes sharply at the line and falls
// off smoothly, giving the soft bloom that reads as "neon".
float neonLine( vec2 uv, float wave, float thickness ) {
    float dist = abs( uv.y - wave );
    // Core glow: inverse distance falloff, clamped for a bright core.
    return thickness / ( dist + 1e-4 );
}

// Animated wave shape for a tube, parameterised by a phase offset
// so each tube drifts independently.
float waveShape( float x, float t, float phase ) {
    return  0.18 * sin( x * 2.4 + t * 1.1 + phase )
          + 0.10 * sin( x * 5.1 - t * 0.7 + phase * 1.7 )
          + 0.05 * sin( x * 9.3 + t * 1.9 + phase * 0.3 );
}

// ── Procedural detail background ───────────────────────────────
// Hash → value noise → fBm → domain warping. This builds up a
// detailed, organic neon field per fragment (no blocky grid).

float hash( vec2 p ) {
    p = fract( p * vec2( 123.34, 456.21 ) );
    p += dot( p, p + 45.32 );
    return fract( p.x * p.y );
}

// Smooth value noise from the hashed lattice.
float valueNoise( vec2 p ) {
    vec2 i = floor( p );
    vec2 f = fract( p );
    f = f * f * ( 3.0 - 2.0 * f );          // smootherstep interpolation

    float a = hash( i + vec2( 0.0, 0.0 ) );
    float b = hash( i + vec2( 1.0, 0.0 ) );
    float c = hash( i + vec2( 0.0, 1.0 ) );
    float d = hash( i + vec2( 1.0, 1.0 ) );

    return mix( mix( a, b, f.x ), mix( c, d, f.x ), f.y );
}

// Fractal Brownian motion: stack noise octaves for fine detail.
float fbm( vec2 p ) {
    float sum = 0.0;
    float amp = 0.5;
    mat2  rot = mat2( 0.8, -0.6, 0.6, 0.8 );   // rotate each octave
    for ( int i = 0; i < 6; i++ ) {
        sum += amp * valueNoise( p );
        p    = rot * p * 2.0;
        amp *= 0.5;
    }
    return sum;
}

// Detailed flowing background: domain-warped fBm tinted with neon.
vec3 detailBackground( vec2 uv, float t ) {
    vec2 p = uv * 3.0;

    // Domain warp: feed fBm into itself for swirling filaments.
    vec2 q = vec2( fbm( p + vec2( 0.0, t * 0.15 ) ),
                   fbm( p + vec2( 5.2, 1.3 - t * 0.12 ) ) );

    vec2 r = vec2( fbm( p + 2.0 * q + vec2( 1.7, 9.2 ) + t * 0.10 ),
                   fbm( p + 2.0 * q + vec2( 8.3, 2.8 ) - t * 0.08 ) );

    float f = fbm( p + 2.0 * r );

    // Map the field to neon hues; sharpen with a power curve so the
    // detail stays crisp rather than washing out to a flat haze.
    vec3 col = neonPalette( f + t * 0.04 + length( q ) * 0.3 );
    float intensity = pow( clamp( f * 1.1, 0.0, 1.0 ), 2.2 );

    return col * intensity * 0.45;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Centered, aspect-correct coordinates in roughly [-1, 1].
    vec2 uv = ( fragCoord - 0.5 * iResolution.xy ) / iResolution.y;

    float t = iTime;

    vec3 col = vec3( 0.0 );

    // ── Detailed procedural background ──────────────────────────
    col += detailBackground( uv, t );

    // ── Neon tubes ──────────────────────────────────────────────
    const int TUBES = 4;
    for ( int i = 0; i < TUBES; i++ ) {
        float fi    = float( i );
        float phase = fi * 1.7;

        float wave  = waveShape( uv.x, t, phase ) + ( fi - 1.5 ) * 0.22;
        float glow  = neonLine( uv, wave, 0.012 );

        // Each tube cycles its own hue over time.
        vec3 tint   = neonPalette( fi * 0.18 + t * 0.05 );

        col += tint * glow;
    }

    // ── Tone shaping ────────────────────────────────────────────
    // Soft bloom feel: lift mids, keep the dark background deep.
    col = 1.0 - exp( -col * 1.4 );

    // Subtle scanline shimmer for the retro CRT vibe.
    col *= 0.92 + 0.08 * sin( fragCoord.y * 1.5 + t * 4.0 );

    // Vignette to focus the glow toward the center.
    float vig = 1.0 - 0.5 * dot( uv, uv );
    col *= vig;

    fragColor = vec4( col, 1.0 );
}
