// Orilla del agua: las teselas del suelo que tocan agua, con el mismo atlas y la
// misma UV que el resto del suelo, menos los texeles que la mascara da por agua.
// Por el hueco se ve la lamina, hundida debajo (water_pixel.gdshader).
//
// Tiene que salir igual que ground_pixel.tres, texel a texel, o la orilla se
// leeria como un parche: difuso Lambert, sin especular, rugoso y el atlas con
// source_color, que es lo que hace StandardMaterial3D con albedo_texture.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

#include "res://assets/game/shaders/shore_mask.gdshaderinc"

uniform sampler2D ground_atlas : source_color, filter_nearest, repeat_disable;

void vertex() {
	shore_texel = VERTEX.xz * texels_per_cell;
}

void fragment() {
	if (is_water(ivec2(floor(shore_texel)))) {
		discard;
	}
	ALBEDO = texture(ground_atlas, UV).rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
