shader_type canvas_item;
render_mode unshaded;

// ─── Resolução / Pixelação ────────────────────────────────────
uniform float resolucao_x : hint_range(80.0, 640.0)  = 240.0;  // menor = mais pixelado
uniform float resolucao_y : hint_range(60.0, 480.0)  = 180.0;

// ─── Cor (PS1 = 15-bit = 32 níveis por canal) ────────────────
uniform float color_depth   : hint_range(4.0, 64.0)  = 28.0;   // PS1-like
uniform float saturacao     : hint_range(0.0, 2.0)   = 1.06;
uniform float brilho        : hint_range(0.5, 1.5)   = 0.97;
uniform float contraste     : hint_range(0.5, 2.0)   = 1.08;

// ─── Dithering PS1 ───────────────────────────────────────────
uniform float dither_force  : hint_range(0.0, 1.0)   = 0.18;   // força do dither

// ─── Tom quente ───────────────────────────────────────────────
uniform float tom_quente    : hint_range(0.0, 0.2)   = 0.022;

// ─── Chuvisco TV ─────────────────────────────────────────────
uniform float static_intensity : hint_range(0.0, 0.25) = 0.018;
uniform float static_speed     : hint_range(0.0, 20.0) = 12.0;

// ─── Grain ───────────────────────────────────────────────────
uniform float grain         : hint_range(0.0, 0.5)   = 0.012;

// ─── Flicker ─────────────────────────────────────────────────
uniform float flicker       : hint_range(0.0, 0.08)  = 0.010;

// ─── Scanlines ───────────────────────────────────────────────
uniform float scanline_force : hint_range(0.0, 1.0)  = 0.10;

// ─── Vignette ────────────────────────────────────────────────
uniform float vignette_size : hint_range(0.0, 3.0)   = 0.28;

// ─── Helpers ─────────────────────────────────────────────────
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(127.1, 311.7))) * 43758.5453);
}

// Matriz de dithering Bayer 4x4 (PS1 usava isso pra simular transparência)
float bayer4(vec2 pos) {
    int x = int(mod(pos.x, 4.0));
    int y = int(mod(pos.y, 4.0));
    // Bayer 4x4 normalizado 0..1
    float mat[16];
    mat[0]  =  0.0/16.0; mat[1]  =  8.0/16.0; mat[2]  =  2.0/16.0; mat[3]  = 10.0/16.0;
    mat[4]  = 12.0/16.0; mat[5]  =  4.0/16.0; mat[6]  = 14.0/16.0; mat[7]  =  6.0/16.0;
    mat[8]  =  3.0/16.0; mat[9]  = 11.0/16.0; mat[10] =  1.0/16.0; mat[11] =  9.0/16.0;
    mat[12] = 15.0/16.0; mat[13] =  7.0/16.0; mat[14] = 13.0/16.0; mat[15] =  5.0/16.0;
    return mat[y * 4 + x];
}

void fragment() {
    vec2 uv = UV;


    // ── Pixelação (snap de UV em grid baixo) ──────────────────
    uv.x = floor(uv.x * resolucao_x + 0.5) / resolucao_x;
    uv.y = floor(uv.y * resolucao_y + 0.5) / resolucao_y;

    // ── Cor base ──────────────────────────────────────────────
    vec4 cor = texture(SCREEN_TEXTURE, uv);

    // ── Dithering Bayer (PS1-style, antes do banding) ─────────
    vec2 screen_pos = UV * vec2(resolucao_x, resolucao_y);
    float threshold = bayer4(floor(screen_pos)) - 0.5;
    cor.rgb += threshold * dither_force * (1.0 / color_depth);

    // ── Banding de cor (color depth reduzida) ─────────────────
    cor.r = floor(cor.r * color_depth) / color_depth;
    cor.g = floor(cor.g * color_depth) / color_depth;
    cor.b = floor(cor.b * color_depth) / color_depth;

    // ── Contraste + Saturação ─────────────────────────────────
    cor.rgb = (cor.rgb - 0.5) * contraste + 0.5;
    float luma = dot(cor.rgb, vec3(0.299, 0.587, 0.114));
    cor.rgb = mix(vec3(luma), cor.rgb, saturacao);

    // ── Tom quente ────────────────────────────────────────────
    cor.r += tom_quente * 0.6;
    cor.g += tom_quente * 0.3;

    // ── Brilho ────────────────────────────────────────────────
    cor.rgb *= brilho;

    // ── Chuvisco de TV ────────────────────────────────────────
    float noise1 = rand(uv * 12.0 + TIME * static_speed);
    float noise2 = rand(uv * vec2(23.7, 41.3) + TIME * static_speed * 1.1);
    float chuvisco = (noise1 * 0.65 + noise2 * 0.35) - 0.5;
    cor.rgb += chuvisco * static_intensity * 2.8;

    // ── Grain ─────────────────────────────────────────────────
    float grain_noise = rand(uv + vec2(TIME * 0.08, TIME * 0.12));
    cor.rgb += (grain_noise - 0.5) * grain;

    // ── Flicker ───────────────────────────────────────────────
    float flick = 1.0 + (rand(vec2(floor(TIME * 12.0), 0.0)) - 0.5) * flicker;
    cor.rgb *= flick;

    // ── Scanlines ─────────────────────────────────────────────
    float scan = mod(floor(UV.y * resolucao_y), 2.0);
    cor.rgb -= scan * scanline_force;

    // ── Vignette ──────────────────────────────────────────────
    vec2 d = UV - vec2(0.5);
    float v = smoothstep(0.45, 0.75, length(d) * vignette_size);
    cor.rgb *= 1.0 - v * 0.35;

    cor.rgb = clamp(cor.rgb, 0.0, 1.0);
    COLOR = cor;
}
