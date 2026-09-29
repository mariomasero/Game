// Arbol de pixel art, dibujado en dos capas (copa y tronco), que se mece con el
// viento. Codigo comun de las dos variantes: tree_sway.gdshader (opaca, la de
// siempre) y tree_sway_faded.gdshader (la copa translucida, mientras tapa al
// personaje). Las variantes declaran shader_type, render_mode y los samplers.
//
// Lo dibuja un quad vertical de cara a la camara, a 1 pixel de pantalla por
// texel del dibujo, como el suelo y los bloques. Nada se estira: cada pixel de
// pantalla lee un texel ENTERO del dibujo desplazado un numero ENTERO de texeles.
// Asi el arbol se mueve sin inventar colores ni temblar a medio pixel
// (decisiones 010 y 011).
//
// Tres movimientos superpuestos, de lento a rapido, como en un arbol de verdad:
//
// 1. Flexion. El arbol entero se inclina con la racha y oscila despacio a su
//    frecuencia propia. Crece con el cuadrado de la altura: el pie no se mueve y
//    la punta es la que mas viaja, asi que el tronco se dobla en escalera de
//    pixeles. Copa y tronco se desplazan lo mismo en cada fila y siguen
//    encajados.
// 2. Agitacion de la copa. Masas de hojas del tamano de un racimo se desplazan
//    un texel cada una por su lado; mas en el borde y arriba que en el centro,
//    que esta resguardado. Una onda cruza la copa a favor del viento: se ve pasar
//    la racha. Donde las hojas se apartan asoman las ramas de la capa del tronco.
// 3. Destellos. Durante la racha, alguna hoja al sol pasa un instante al tono de
//    paleta siguiente, como cuando el viento le da la vuelta.
//
// Las rachas son la misma onda que mueve la hierba (grass_tuft.gdshader, mismos
// valores por defecto): una racha cruza el prado y los arboles a la vez.

// Rectangulo que cubre el quad, en texeles del dibujo (origen arriba a la
// izquierda, y hacia abajo). Sobresale del dibujo lo que puede viajar la copa
// (5 texeles con los valores por defecto, sople hacia donde sople), esta
// centrado en el pie del tronco y acaba abajo en la fila del suelo. Su ancho es
// par para que los bordes caigan entre pixeles con el centro en la raiz. Tiene
// que medir lo mismo que el QuadMesh de arbol.tscn (tests/test_tree.gd).
uniform vec2 rect_min = vec2(-2.0, 0.0);
uniform vec2 rect_size = vec2(148.0, 182.0);
// Fila de la punta de la copa: la flexion vale 0 en el suelo y 1 aqui.
uniform float top_row = 4.0;
// Centro y semiejes de la copa en texeles, para agitar mas el borde.
uniform vec2 crown_center = vec2(69.0, 75.0);
uniform vec2 crown_radius = vec2(66.0, 71.0);

// Lo que mide un pixel de pantalla en unidades de mundo en X, Y y Z: TEXEL,
// TEXEL / cos p y TEXEL / sen p a 55 grados (VillageMetrics). Como los objetos
// del pueblo, parte de DEFAULT_PITCH_DEGREES.
uniform vec3 pixel_step = vec3(0.03125, 0.0544827, 0.0381492);

uniform vec2 wind_direction = vec2(1.0, 0.3);
uniform float wind_speed = 1.2;      // rapidez con que recorren el pueblo las rachas
uniform float wind_scale = 0.35;     // cuanto de ancha es cada racha: menos, mas ancha
uniform float wind_strength : hint_range(0.0, 2.0) = 1.0;  // 0 quieto, 1 brisa

uniform float bend_texels = 2.0;     // cuanto se inclina la punta con la racha entera
uniform float sway_texels = 1.2;     // oscilacion de la punta alrededor de esa inclinacion
uniform float sway_frequency = 0.3;  // Hz: un arbol grande oscila despacio
uniform float rustle_texels = 1.4;   // cuanto viaja un racimo del borde con la racha
uniform vec2 rustle_size = vec2(11.0, 11.0);  // ancho y alto de un racimo, en texeles;
                                              // mas ancho que alto: pisos de ramas
uniform float rustle_speed = 0.9;    // rapidez con que cambian los racimos
uniform vec2 rustle_axes = vec2(1.0, 0.6);  // cuanto viaja un racimo en X y en Y: las
                                            // ramas de un abeto suben y bajan mas
uniform float rustle_wave_length = 70.0;  // texeles entre dos ondas que cruzan la copa
uniform float rustle_wave_speed = 55.0;   // texeles por segundo
uniform float shimmer : hint_range(0.0, 1.0) = 0.35;
// Un texel de cada tono de la copa al sol, de oscuro a claro, en coordenadas
// del dibujo. Un destello cambia cada tono por el siguiente; el ultimo solo es
// destino. Se dan texeles y no colores porque el color de destino se copia de la
// propia textura: convertido a mano desde sRGB, la tarjeta lo decodifica una
// unidad distinto y el destello salia con un verde que no estaba en la paleta
// (medido en el abeto: 457 pixeles en 40 fotogramas; es lo mismo que obliga al
// agua a leer sus tone_*). tests/test_tree.gd comprueba que son de la copa.
uniform vec2 lit_texel_0 = vec2(66.0, 7.0);
uniform vec2 lit_texel_1 = vec2(63.0, 5.0);
uniform vec2 lit_texel_2 = vec2(60.0, 5.0);
uniform vec2 lit_texel_3 = vec2(53.0, 11.0);

#ifdef FADED
// Opacidad de la copa, de cada arbol por separado: la escribe VillageTree
// mientras la copa tapa al personaje.
instance uniform float canopy_opacity : hint_range(0.0, 1.0) = 1.0;
#endif

// El tiempo avanza a saltos, como el agua: el dibujo cambia a un ritmo de
// animacion pixel art y un racimo no parpadea entre dos texeles cada fotograma.
uniform float time_step = 0.1;

// Pie del arbol en mundo; da la racha y la semilla de cada arbol.
varying flat vec3 v_root;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Ruido de valor suave, entre -1 y 1.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

void vertex() {
	// Con world_vertex_coords VERTEX y NORMAL llegan en mundo. El quad se rehace
	// desde su UV alrededor de su centro: asi mide rect_size pixeles en pantalla y
	// sigue de cara a la camara aunque alguien gire el objeto en el editor.
	vec3 center = NODE_POSITION_WORLD;
	vec2 half_size = rect_size * pixel_step.xy * 0.5;
	VERTEX = center + vec3((UV.x * 2.0 - 1.0) * half_size.x,
		(1.0 - UV.y * 2.0) * half_size.y, 0.0);
	// Luz de suelo, como la hierba: el sombreado ya esta pintado en el dibujo y
	// con la normal arriba la copa al sol sale con los colores de su textura.
	NORMAL = vec3(0.0, 1.0, 0.0);
	v_root = center - vec3(0.0, half_size.y, 0.0);
}

void fragment() {
	vec2 texel = floor(rect_min + UV * rect_size);
	float t = floor(TIME / time_step) * time_step;
	float ground_row = rect_min.y + rect_size.y;
	vec2 wind_dir = normalize(wind_direction);
	float seed = hash12(floor(v_root.xz * 4.0)) * TAU;

	// Racha: la onda de la hierba, medida en el pie del arbol.
	float gust = 0.5 + 0.5 * sin(dot(v_root.xz, wind_dir) * wind_scale - t * wind_speed);
	gust *= gust;
	float wind = wind_strength * (0.25 + 0.75 * gust);

	// 1. Flexion. Dos senos de frecuencias sin relacion simple para que la
	// oscilacion no se repita a ojos vista.
	float height = clamp((ground_row - texel.y) / (ground_row - top_row), 0.0, 1.0);
	float sway = sin(TAU * sway_frequency * t + seed)
		+ 0.35 * sin(TAU * sway_frequency * 2.37 * t + seed * 1.7);
	float bend = (wind_dir.x * wind * bend_texels
		+ sway * sway_texels * (0.3 + 0.7 * wind)) * height * height;

	// 2. Agitacion: un ruido por eje que deriva despacio.
	vec2 q = texel / rustle_size + seed;
	float drift = t * rustle_speed;
	vec2 rustle = vec2(
		value_noise(q + vec2(drift, 0.37 * drift)),
		value_noise(q * 1.31 + vec2(-0.61 * drift, drift) + 19.7));
	float along = wind_dir.x >= 0.0 ? texel.x : -texel.x;
	float wave = 0.5 + 0.5 * sin(TAU * (along - rustle_wave_speed * t) / rustle_wave_length);
	float edge = smoothstep(0.3, 1.0, length((texel - crown_center) / crown_radius));
	// Aun sin racha las hojas del borde no se estan del todo quietas.
	float rustle_wind = wind_strength * (0.5 + 0.5 * gust);
	rustle *= rustle_texels * rustle_wind * (0.35 + 0.65 * edge)
		* (0.5 + 0.5 * height) * (0.4 + 0.6 * wave) * rustle_axes;

	vec2 canopy_shift = round(vec2(bend, 0.0) + rustle);
	vec2 trunk_shift = vec2(round(bend), 0.0);

	vec2 size = vec2(textureSize(canopy_texture, 0));
	vec2 canopy_uv = (texel - canopy_shift + 0.5) / size;
	vec4 color = texture(canopy_texture, canopy_uv);
	bool from_canopy = color.a >= 0.5;
	if (!from_canopy) {
		color = texture(trunk_texture, (texel - trunk_shift + 0.5) / size);
	} else if (shimmer > 0.0) {
		// 3. Destellos. Van pegados al dibujo (texel - shift) para que la hoja que
		// brilla se mueva con su racimo, y duran dos pasos de tiempo.
		vec3 tone = texture(canopy_raw, canopy_uv).rgb;
		ivec2 lit_texels[4] = ivec2[4](ivec2(lit_texel_0), ivec2(lit_texel_1),
			ivec2(lit_texel_2), ivec2(lit_texel_3));
		for (int i = 0; i < 3; i++) {
			// Los dos salen del mismo PNG sin conversion: iguales si es el mismo byte.
			if (tone == texelFetch(canopy_raw, lit_texels[i], 0).rgb) {
				vec2 leaf = floor((texel - canopy_shift) / vec2(2.0, 1.0));
				float slot = floor(t / (2.0 * time_step));
				float chance = 0.25 * shimmer * (0.15 + 0.85 * gust) * (0.3 + 0.7 * edge);
				if (hash12(leaf + vec2(slot * 7.13) + seed) < chance) {
					color.rgb = texelFetch(canopy_texture, lit_texels[i + 1], 0).rgb;
				}
				break;
			}
		}
	}

	ALBEDO = color.rgb;
	ROUGHNESS = 1.0;
#ifdef FADED
	// Variante fundida: mezcla de verdad, como los muros que tapan (WallsFaded en
	// test_room.gd). Solo la copa se transparenta; el tronco y sus ramas siguen
	// opacos. Lo que no es dibujo se descarta para no ensuciar lo de detras.
	if (color.a < 0.5) {
		discard;
	}
	ALPHA = from_canopy ? canopy_opacity : 1.0;
#else
	// Recorte y no mezcla, como la hierba: la mezcla inventa colores en el borde.
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
#endif
}
