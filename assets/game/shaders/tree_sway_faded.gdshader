// Arbol de pixel art que se mece con el viento, variante con la copa translucida.
// La usa VillageTree mientras la copa tapa al personaje; el resto del tiempo el
// arbol se dibuja con tree_sway.gdshader. Mismo codigo (tree_sway.gdshaderinc),
// asi que el paso de una a otra no mueve ni un pixel.
//
// Como los muros que tapan, es transparente de verdad: no proyecta sombra, y
// mientras se ve la variante opaca sigue dibujandose solo en el mapa de sombras.

shader_type spatial;
render_mode world_vertex_coords, diffuse_lambert, specular_disabled, cull_disabled,
	shadows_disabled,
	blend_mix;

#define FADED

// Los samplers van en cada variante y no en el include: la guarda de pixel
// (tests/test_pixel_settings_guard.gd) lee el codigo del shader del material y
// exige filter_nearest en cada sampler. Capas del mismo tamano y encajadas al
// texel: la copa encima del tronco da el arbol completo. Nearest y sin repetir:
// fuera del dibujo se lee su borde, que en las dos capas es transparente.
uniform sampler2D canopy_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D trunk_texture : source_color, filter_nearest, repeat_disable;
// La misma copa sin conversion sRGB: devuelve los bytes del PNG entre 255, asi
// que se compara exacta con los texeles lit_texel_*.
uniform sampler2D canopy_raw : filter_nearest, repeat_disable;

#include "res://assets/game/shaders/tree_sway.gdshaderinc"
