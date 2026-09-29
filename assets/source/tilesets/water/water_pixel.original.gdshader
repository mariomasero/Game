// Agua pixel art: textura en espacio de mundo, desplazada por píxeles enteros.
// Pensada para el renderer Compatibility del proyecto (material sin iluminación, como terminal_pixel.tres).
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D water_texture : source_color, filter_nearest, repeat_enable;
// Tamaño en unidades de mundo (X, Z) de una repetición de la textura.
// X: 128 px × 0,0375 u/px = 4,8 u, la misma densidad que el personaje.
// Z: 4,8 / sin(55°) ≈ 5,86 u, para que con la cámara inclinada 55° los píxeles salgan cuadrados.
// Con cámara cenital, usar (4.8, 4.8).
uniform vec2 world_units_per_tile = vec2(4.8, 5.86);
// Velocidad en píxeles de textura por segundo; se avanza siempre en pasos enteros.
uniform vec2 texels_per_second = vec2(3.0, 1.0);

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 tex_size = vec2(textureSize(water_texture, 0));
	vec2 uv = world_xz / world_units_per_tile;
	vec2 offset = floor(texels_per_second * TIME) / tex_size;
	ALBEDO = texture(water_texture, uv + offset).rgb;
}
