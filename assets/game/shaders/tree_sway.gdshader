// Arbol de pixel art que se mece con el viento, variante opaca. El codigo y la
// explicacion de los tres movimientos estan en tree_sway.gdshaderinc.

shader_type spatial;
// shadows_disabled: el arbol proyecta sombra pero no la recibe. Un quad vertical
// cae en la penumbra de su propia sombra y el filtrado le salpicaba texeles una
// unidad mas oscuros (medido: 1059 de 14343 fuera de su color; sin recibir
// sombra, ninguno).
render_mode world_vertex_coords, diffuse_lambert, specular_disabled, cull_disabled,
	shadows_disabled;

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
