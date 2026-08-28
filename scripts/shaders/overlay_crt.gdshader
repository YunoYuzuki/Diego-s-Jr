shader_type canvas_item;
render_mode unshaded;

// ─── Cor ───────────────────────────────────────────────────────
uniform float saturacao     : hint_range(0.0, 2.0)   = 1.05;
uniform float brilho        : hint_range(0.5, 1.5)   = 0.97;   // <- controlado por Camera.gd (emoção/jumpscare)
uniform float contraste     : hint_range(0.5, 2.0)   = 1.05;

// ─── Tom quente ─────────────────────────────────────────────────
uniform float tom_quente    : hint_range(0.0, 0.2)   = 0.02;
uniform float tint_emocional : hint_range(0.0, 0.3)  = 0.0;    // <- controlado por Camera.gd (SHADER_POR_EMOCAO)

// ─── CRT: curvatura da tela ──────────────────────────────────────
uniform float curvatura      : hint_range(0.0, 0.01)  = 0.006;   // 0 = tela reta

// ─── CRT: aberração cromática (separação R/G/B nas bordas) ───────
uniform float aberracao_cromatica : hint_range(0.0, 0.01) = 0.0018;

// ─── CRT: scanlines (linhas horizontais escuras) ─────────────────
uniform float scanline_force : hint_range(0.0, 1.0)  = 0.22;
uniform float scanline_escala : hint_range(0.5, 3.0) = 2.1;    // >1 = linhas mais finas/mais juntas

// ─── CRT: máscara de fósforo (faixas RGB verticais bem sutis) ────
uniform float mascara_forca : hint_range(0.0, 1.0)   = 0.12;

// ─── Brilho entre scanlines (glow simples de fósforo) ────────────
uniform float glow_scanline : hint_range(0.0, 1.0)   = 0.15;

// ─── Chuvisco de TV ───────────────────────────────────────────────
uniform float static_intensity : hint_range(0.0, 0.25) = 0.018; // <- controlado por Camera.gd
uniform float static_speed     : hint_range(0.0, 20.0) = 12.0;

// ─── Grain ─────────────────────────────────────────────────────
uniform float grain         : hint_range(0.0, 0.5)   = 0.012;  // <- controlado por Camera.gd

// ─── Flicker (tremor de brilho, tipo tubo desregulado) ───────────
uniform float flicker       : hint_range(0.0, 0.08)  = 0.012;

// ─── Vignette ────────────────────────────────────────────────────
uniform float vignette_size : hint_range(0.0, 3.0)   = 0.30;   // <- controlado por Camera.gd

// ─── Helpers ─────────────────────────────────────────────────────
float rand(vec2 co) {
	return fract(sin(dot(co, vec2(127.1, 311.7))) * 43758.5453);
}

// Deforma a UV como se a tela fosse um tubo de vidro curvo (barrel distortion).
// Retorna a UV distorcida; quem chamar decide o que fazer se ela sair de [0,1].
vec2 curvar_uv(vec2 uv) {
	vec2 centro = uv * 2.0 - 1.0; // -1..1
	float r2 = dot(centro, centro);
	centro *= 1.0 + curvatura * r2;
	return centro * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = curvar_uv(UV);

	// Fora da "moldura de vidro" curva -> preto (borda do tubo)
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}

	// SCREEN_TEXTURE vem invertido verticalmente nesse setup
	vec2 uv_tela = vec2(uv.x, 1.0 - uv.y);

	// ── Aberração cromática (mais forte perto da borda) ─────────
	vec2 dir_centro = uv - vec2(0.5);
	float dist_centro = length(dir_centro);
	vec2 deslocamento = dir_centro * aberracao_cromatica * dist_centro;

	vec4 cor;
	cor.r = texture(SCREEN_TEXTURE, uv_tela + deslocamento).r;
	cor.g = texture(SCREEN_TEXTURE, uv_tela).g;
	cor.b = texture(SCREEN_TEXTURE, uv_tela - deslocamento).b;
	cor.a = 1.0;

	// ── Contraste + Saturação ────────────────────────────────────
	cor.rgb = (cor.rgb - 0.5) * contraste + 0.5;
	float luma = dot(cor.rgb, vec3(0.299, 0.587, 0.114));
	cor.rgb = mix(vec3(luma), cor.rgb, saturacao);

	// ── Tom quente ────────────────────────────────────────────────
	cor.r += tom_quente * 0.6;
	cor.g += tom_quente * 0.3;

	// ── Tom emocional (avermelhado conforme a tensão de Laura) ────
	cor.r += tint_emocional;
	cor.g -= tint_emocional * 0.4;
	cor.b -= tint_emocional * 0.4;

	// ── Brilho ──────────────────────────────────────────────────
	cor.rgb *= brilho;

	// ── Chuvisco de TV ────────────────────────────────────────────
	float noise1 = rand(uv * 12.0 + TIME * static_speed);
	float noise2 = rand(uv * vec2(23.7, 41.3) + TIME * static_speed * 1.1);
	float chuvisco = (noise1 * 0.65 + noise2 * 0.35) - 0.5;
	cor.rgb += chuvisco * static_intensity * 2.8;

	// ── Grain ─────────────────────────────────────────────────────
	float grain_noise = rand(uv + vec2(TIME * 0.08, TIME * 0.12));
	cor.rgb += (grain_noise - 0.5) * grain;

	// ── Flicker ───────────────────────────────────────────────────
	float flick = 1.0 + (rand(vec2(floor(TIME * 12.0), 0.0)) - 0.5) * flicker;
	cor.rgb *= flick;

	// ── Scanlines (baseadas na resolução REAL da tela, não pixelado) ──
	float linhas_tela = 1.0 / SCREEN_PIXEL_SIZE.y;              // altura real em pixels
	float linha = sin(uv.y * linhas_tela * 3.14159 * scanline_escala);
	float scan = smoothstep(-1.0, 1.0, linha);
	cor.rgb -= (1.0 - scan) * scanline_force * 0.5;
	cor.rgb += scan * glow_scanline * 0.05;

	// ── Máscara de fósforo (faixas RGB verticais bem sutis) ────────
	float coluna_tela = 1.0 / SCREEN_PIXEL_SIZE.x;
	float fase = mod(floor(uv.x * coluna_tela), 3.0);
	vec3 mascara = vec3(1.0);
	if (fase < 1.0) {
		mascara = vec3(1.0, 1.0 - mascara_forca, 1.0 - mascara_forca);
	} else if (fase < 2.0) {
		mascara = vec3(1.0 - mascara_forca, 1.0, 1.0 - mascara_forca);
	} else {
		mascara = vec3(1.0 - mascara_forca, 1.0 - mascara_forca, 1.0);
	}
	cor.rgb *= mix(vec3(1.0), mascara, mascara_forca);

	// ── Vignette ───────────────────────────────────────────────────
	vec2 d = uv - vec2(0.5);
	float v = smoothstep(0.45, 0.75, length(d) * vignette_size);
	cor.rgb *= 1.0 - v * 0.35;

	cor.rgb = clamp(cor.rgb, 0.0, 1.0);
	COLOR = cor;
}