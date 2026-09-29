// Mascara de orilla del agua (WaterSurface.shore_mask): un texel por texel de
// mundo, 1 donde hay agua. La leen la lamina (water_pixel.gdshader) y la orilla
// (water_shore.gdshader), para que las dos acaben el agua en el mismo texel.
//
// Las mallas del agua van en unidades de celda y el nodo lleva la escala
// anisotropa, asi que VERTEX.xz por texels_per_cell es ya el texel de mundo, sin
// deshacer ninguna escala.

uniform sampler2D shore_mask : filter_nearest, repeat_disable;
// Texel de mundo del texel (0, 0) de la mascara.
uniform ivec2 mask_origin;
uniform float texels_per_cell = 32.0;

// Texel de mundo del fragmento: se asigna en vertex() con VERTEX.xz *
// texels_per_cell y se lee en fragment() con ivec2(floor(shore_texel)). Directo
// en las dos funciones y no a traves de otra, porque los shaders de Godot no
// dejan escribir un varying desde una funcion propia.
varying vec2 shore_texel;

// Fuera de la mascara todo es tierra: solo hay agua en las teselas que tocan una
// casilla de agua, y la mascara las cubre todas.
bool is_water(ivec2 texel) {
	ivec2 p = texel - mask_origin;
	ivec2 size = textureSize(shore_mask, 0);
	if (any(lessThan(p, ivec2(0))) || any(greaterThanEqual(p, size))) {
		return false;
	}
	return texelFetch(shore_mask, p, 0).r > 0.5;
}
