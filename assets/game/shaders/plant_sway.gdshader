// Planta de pixel art (arbusto, hierba, flor, seta o roca) que se mece con el
// viento. Las escenas las genera tools/build_plants.gd, una por dibujo.
//
// Lo dibuja un quad vertical de cara a la camara, a 1 pixel de pantalla por
// texel del dibujo, como los arboles (tree_sway.gdshaderinc). Nada se estira:
// cada pixel de pantalla lee un texel ENTERO del dibujo desplazado un numero
// ENTERO de texeles, asi que la planta se mueve sin inventar colores ni temblar a
// medio pixel (decisiones 010 y 011).
//
// Solo hay un movimiento, la flexion del arbol: la planta entera se inclina con
// la racha y oscila a su frecuencia propia, mas cuanto mas arriba. El pie no se
// mueve y la punta es la que mas viaja, asi que los tallos se doblan en escalera
// de pixeles. La agitacion de racimos y los destellos del arbol no hacen falta a
// este tamano. Con bend_texels y sway_texels a 0 (setas y rocas) queda quieta.
//
// Las rachas son la misma onda que mueve la hierba y los arboles (mismos valores
// por defecto): una racha cruza el prado, las plantas y los arboles a la vez.

shader_type spatial;
// shadows_disabled: proyecta sombra pero no la recibe, como el arbol. Un quad
// vertical cae en la penumbra de su propia sombra y el filtrado lo salpica de
// texeles una unidad mas oscuros.
render_mode world_vertex_coords, diffuse_lambert, specular_disabled, cull_disabled,
	shadows_disabled;

// Nearest y sin repetir. Lo que cae fuera del dibujo se descarta a mano: con
// repeat_disable se leeria el borde, y algunos dibujos llegan hasta el borde.
uniform sampler2D plant_texture : source_color, filter_nearest, repeat_disable;

// Rectangulo que cubre el quad, en texeles del dibujo (origen arriba a la
// izquierda, y hacia abajo). Sobresale del dibujo por los lados lo que puede
// viajar la punta, esta centrado en el pie (el centro de la fila de abajo) y
// acaba abajo en la fila del suelo. Su ancho es par para que los bordes caigan
// entre pixeles con el centro en la raiz. Tiene que medir lo mismo que el
// QuadMesh de la escena (tests/test_plants.gd).
uniform vec2 rect_min = vec2(-3.0, 0.0);
uniform vec2 rect_size = vec2(70.0, 64.0);
// Fila de arriba del dibujo: la flexion vale 0 en el suelo y 1 aqui.
uniform float top_row = 0.0;

// Lo que mide un pixel de pantalla en unidades de mundo en X, Y y Z: TEXEL,
// TEXEL / cos p y TEXEL / sen p a 55 grados (VillageMetrics). Como los objetos
// del pueblo, parte de DEFAULT_PITCH_DEGREES.
uniform vec3 pixel_step = vec3(0.03125, 0.0544827, 0.0381492);

uniform vec2 wind_direction = vec2(1.0, 0.3);
uniform float wind_speed = 1.2;      // rapidez con que recorren el pueblo las rachas
uniform float wind_scale = 0.35;     // cuanto de ancha es cada racha: menos, mas ancha
uniform float wind_strength : hint_range(0.0, 2.0) = 1.0;  // 0 quieto, 1 brisa

// Texeles que viaja la punta. El maximo es bend_texels + 1,35 * sway_texels, y
// rect_min.x tiene que dejarle sitio a los dos lados.
uniform float bend_texels = 1.5;     // cuanto se inclina la punta con la racha entera
uniform float sway_texels = 1.0;     // oscilacion de la punta alrededor de esa inclinacion
uniform float sway_frequency = 0.6;  // Hz: una mata ligera oscila mas deprisa que un arbol

// El tiempo avanza a saltos, como en el arbol y el agua: ritmo de animacion pixel
// art, y un tallo no parpadea entre dos texeles cada fotograma.
uniform float time_step = 0.1;

// Pie de la planta en mundo; da la racha y la semilla de cada planta.
varying flat vec3 v_root;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	// Con world_vertex_coords VERTEX y NORMAL llegan en mundo. El quad se rehace
	// desde su UV alrededor de su centro: asi mide rect_size pixeles en pantalla y
	// sigue de cara a la camara aunque alguien gire el objeto en el editor.
	vec3 center = NODE_POSITION_WORLD;
	vec2 half_size = rect_size * pixel_step.xy * 0.5;
	VERTEX = center + vec3((UV.x * 2.0 - 1.0) * half_size.x,
		(1.0 - UV.y * 2.0) * half_size.y, 0.0);
	// Luz de suelo, como la hierba y los arboles: el sombreado ya esta pintado en
	// el dibujo y con la normal arriba la planta al sol sale con sus colores.
	NORMAL = vec3(0.0, 1.0, 0.0);
	v_root = center - vec3(0.0, half_size.y, 0.0);
}

void fragment() {
	vec2 texel = floor(rect_min + UV * rect_size);
	float t = floor(TIME / time_step) * time_step;
	float ground_row = rect_min.y + rect_size.y;
	vec2 wind_dir = normalize(wind_direction);
	float seed = hash12(floor(v_root.xz * 4.0)) * TAU;

	// Racha: la onda de la hierba, medida en el pie de la planta.
	float gust = 0.5 + 0.5 * sin(dot(v_root.xz, wind_dir) * wind_scale - t * wind_speed);
	gust *= gust;
	float wind = wind_strength * (0.25 + 0.75 * gust);

	// Flexion. Dos senos de frecuencias sin relacion simple para que la
	// oscilacion no se repita a ojos vista.
	float height = clamp((ground_row - texel.y) / max(ground_row - top_row, 1.0), 0.0, 1.0);
	float sway = sin(TAU * sway_frequency * t + seed)
		+ 0.35 * sin(TAU * sway_frequency * 2.37 * t + seed * 1.7);
	float bend = (wind_dir.x * wind * bend_texels
		+ sway * sway_texels * (0.3 + 0.7 * wind)) * height * height;

	vec2 source = texel - vec2(round(bend), 0.0);
	vec2 size = vec2(textureSize(plant_texture, 0));
	if (any(lessThan(source, vec2(0.0))) || any(greaterThanEqual(source, size))) {
		discard;
	}
	vec4 color = texture(plant_texture, (source + 0.5) / size);

	ALBEDO = color.rgb;
	ROUGHNESS = 1.0;
	// Recorte y no mezcla, como la hierba: la mezcla inventa colores en el borde.
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
