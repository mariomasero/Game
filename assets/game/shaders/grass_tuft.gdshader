// Matas de hierba que se mecen con el viento y se apartan al paso del personaje.
//
// Cada instancia de la MultiMesh es un quad vertical de 16x16 texeles con el pie
// en y = 0; la construye test_room.gd (_build_grass). Nada se simula: el pie se
// queda clavado y solo se desplaza la fila de arriba, asi que la hoja se tuerce
// en escalera de pixeles.
//
// Pixel exacto (decisiones 010 y 011): el desplazamiento se redondea a pixeles
// de pantalla ENTEROS en cada eje del mundo (pixel_step). Sin ese redondeo la
// punta avanzaria fracciones de pixel y el dibujo temblaria.

shader_type spatial;
render_mode world_vertex_coords, diffuse_lambert, specular_disabled;

// Hoja de matas en fila, tools/build_grass_tufts.gd. Nearest y sin repetir: un
// texel de la mata vecina no debe colarse por el borde.
uniform sampler2D tufts : source_color, filter_nearest, repeat_disable;
uniform int variants = 4;

// Lo que mide un pixel de pantalla en unidades de mundo, en X, Y y Z. Con la
// compensacion anisotropa no es el mismo en los tres ejes: TEXEL, TEXEL / cos p
// y TEXEL / sen p. Lo rellena test_room.gd a partir de VillageMetrics.
uniform vec3 pixel_step = vec3(0.03125, 0.0545, 0.0381);

// Alto del quad en mundo, para saber cuanto puede agacharse la punta.
uniform float tuft_height = 0.87;

uniform vec2 wind_direction = vec2(1.0, 0.3);
uniform float wind_strength = 0.06;  // unidades que se mueve la punta con la racha
uniform float wind_speed = 1.2;      // rapidez con que recorren el prado las rachas
uniform float wind_scale = 0.35;     // cuanto de ancha es cada racha: menos, mas ancha

// Pies del personaje en mundo; test_room.gd lo escribe cada fotograma.
uniform vec3 player_position = vec3(1e6);
uniform float push_radius = 0.8;     // hasta donde llega el empuje
uniform float push_distance = 0.22;  // cuanto se aparta la punta junto a los pies
uniform float push_flatten = 0.45;   // fraccion del alto que se agacha junto a los pies

varying flat int v_variant;

void vertex() {
	// Con world_vertex_coords el origen de la instancia es el pie de la mata.
	vec3 root = MODEL_MATRIX[3].xyz;
	// QuadMesh pone v = 0 arriba: tip vale 1 en la punta y 0 en el pie.
	float tip = 1.0 - UV.y;

	vec2 dir_viento = normalize(wind_direction);
	float fase = dot(root.xz, dir_viento) * wind_scale - TIME * wind_speed;
	float racha = 0.5 + 0.5 * sin(fase);
	float temblor = 0.25 * sin(TIME * 3.1 + INSTANCE_CUSTOM.g * 6.2832);
	vec2 viento = dir_viento * wind_strength * (racha * racha + temblor);

	vec2 fuera = root.xz - player_position.xz;
	float dist = length(fuera);
	float empuje = 1.0 - smoothstep(0.0, push_radius, dist);
	vec2 aparta = dist > 0.0001 ? fuera / dist * push_distance * empuje : vec2(0.0);

	vec3 desvio = vec3(viento.x + aparta.x, -push_flatten * tuft_height * empuje,
		viento.y + aparta.y);
	desvio = round(desvio / pixel_step) * pixel_step;
	VERTEX += desvio * tip;

	// Luz de suelo: con la normal hacia arriba la mata recibe la misma luz que el
	// cesped sobre el que crece y no se despega de el como una pegatina.
	NORMAL = vec3(0.0, 1.0, 0.0);
	v_variant = int(round(INSTANCE_CUSTOM.r * float(variants)));
}

void fragment() {
	vec2 uv = vec2((UV.x + float(v_variant)) / float(variants), UV.y);
	vec4 c = texture(tufts, uv);
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
	// Recorte y no mezcla: la mezcla inventa colores fuera de paleta en el borde
	// y saca la mata del paso opaco, donde se ordena por profundidad.
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
