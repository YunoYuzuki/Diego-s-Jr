shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, depth_test_disabled;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float pixel_size : hint_range(0.0, 20.0, 1.0) = 1.0;
uniform float levels : hint_range(1.0, 64.0, 1.0) = 20.0;
uniform vec2 gamma = vec2(0.125, 10.915);

void vertex() {
	// Fixa o quad na frente da câmera em clip space
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 tex_size = vec2(textureSize(screen_texture, 0));
	
	// Pixelização: snap das UVs em blocos de pixel_size
	vec2 pixel_count = tex_size / max(pixel_size * 2.0, 1.0);
	vec2 snapped_uv = floor(SCREEN_UV * pixel_count) / pixel_count;
	
	vec3 color = texture(screen_texture, snapped_uv).rgb;
	
	// Posterização (redução de color depth em N níveis)
	color = floor(color * levels + 0.5) / levels;
	
	// Gamma (dois valores: lift e ganho, como no original)
	// gamma.x = offset escuro, gamma.y = multiplicador
	color = pow(max(color, vec3(0.0)), vec3(gamma.y));
	color = clamp(color + gamma.x, 0.0, 1.0);
	
	ALBEDO = color;
}
