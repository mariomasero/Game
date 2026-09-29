// Agua pixel art quieta: un estanque, no un rio.
//
// Adaptado del water_pixel.gdshader entregado el 24 de septiembre de 2026 (copia
// sin tocar en assets/source/tilesets/water/). El original desplazaba la textura
// entera en diagonal, y el agua se leia como una alfombra arrastrada. Aqui la
// textura se separa en capas por su paleta de cinco colores (base, claro, oscuro,
// onda y destello) y cada capa se mueve a su aire:
//
// - El fondo (base, claro y oscuro) no viaja: solo se balancea un pixel a cada
//   lado, fila a fila, como el reflejo de un agua quieta. Las ondas no se
//   balancean: con el vaiven por filas sus arcos, de dos filas, se partian en
//   rayas sueltas.
// - Las ondas son dos copias de la misma textura que derivan despacio en
//   direcciones distintas y aparecen y desaparecen a trozos, asi que el dibujo
//   no se repite nunca igual.
// - Los destellos no son los de la textura: se encienden y se apagan en puntos
//   fijos del mundo, de uno en uno.
// - En la orilla, una linea de espuma de un pixel que aparece a trozos, y bajo
//   el escalon de tierra una franja un tono mas oscura, la sombra de la pared.
//
// Todo sale de los cinco colores de la textura, leidos de ella, sin mezclas: el agua no mete
// ningun color nuevo en pantalla (decision 010). El tiempo avanza a saltos
// (steps_per_second) y los desplazamientos son de pixel entero.
//
// Ademas, respecto al original:
// - Recibe luz, con los mismos ajustes que ground_pixel.tres (difuso Lambert, sin
//   especular, rugoso), para que se oscurezca bajo la sombra de un muro igual que
//   el cesped de al lado.
// - Lee la textura por texel de mundo (shore_texel), 128 texeles cada 4 celdas:
//   un texel de agua mide lo mismo que uno de suelo (32 por celda).
// - Pinta el escalon de tierra de la orilla. La lamina va depth_texels pixeles
//   por debajo del suelo, asi que el texel de lamina que se ve por un hueco de la
//   orilla esta depth_texels texeles al norte del hueco. Entre los dos, el rayo
//   de la camara atraviesa la franja de tierra que hay bajo el borde: si alguno
//   de esos texeles es tierra, lo que se ve es la pared del estanque y no el
//   agua. Asi el escalon sigue la curva de la orilla sin modelarlo.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

#include "res://assets/game/shaders/shore_mask.gdshaderinc"

uniform sampler2D water_texture : source_color, filter_nearest, repeat_enable;

// Donde esta en water_128.png cada color de su paleta (WaterSurface.PALETTE). El
// shader clasifica cada texel por el mas cercano y pinta leyendo de la textura
// en esos texeles, no con colores escritos aqui: la conversion de sRGB de la
// tarjeta y la de Godot difieren en una unidad en algun canal, y el agua saldria
// con colores que la textura no tiene.
uniform ivec2 tone_base;
uniform ivec2 tone_light;
uniform ivec2 tone_dark;
uniform ivec2 tone_ripple;
uniform ivec2 tone_sparkle;

// Pasos de tiempo por segundo. Mas es mas suave, pero el pixel art se mueve a
// saltos: con 8 el agua se mueve como un sprite animado y no como un video.
uniform float steps_per_second = 8.0;

// Balanceo del fondo: filas que mide una ola y segundos que tarda en pasar.
uniform float sway_rows = 12.0;
uniform float sway_seconds = 2.4;

// Ondas: pixeles por segundo que derivan, lado de los trozos que se encienden y
// se apagan juntos, cada cuantos segundos vuelve a encenderse un trozo y que
// parte de ese tiempo esta encendido.
uniform float ripple_speed = 0.6;
uniform float ripple_block = 24.0;
uniform float ripple_seconds = 5.0;
uniform float ripple_share = 0.55;

// Destellos: uno de cada tantos texeles, cada cuantos segundos y que parte de
// ese tiempo brilla. En la mitad central del brillo le salen cuatro puntas.
uniform float sparkle_every = 700.0;
uniform float sparkle_seconds = 3.5;
uniform float sparkle_share = 0.09;

// Espuma: lado de los trozos de la linea, cada cuantos segundos y que parte del
// tiempo se ve cada trozo.
uniform float foam_block = 4.0;
uniform float foam_seconds = 3.0;
uniform float foam_share = 0.65;
// Filas de sombra bajo el escalon.
uniform int bank_shadow_rows = 2;

// Pixeles que se hunde la lamina: lo que mide el escalon.
uniform int depth_texels = 6;
// El escalon es el relleno de tierra del atlas del suelo, desde su fila de
// arriba. bank_page es el texel de la esquina de esa pagina de 128 x 128.
uniform sampler2D ground_atlas : source_color, filter_nearest, repeat_disable;
uniform ivec2 bank_page;

const int TONE_BASE = 0;
const int TONE_LIGHT = 1;
const int TONE_DARK = 2;
const int TONE_RIPPLE = 3;
const int TONE_SPARKLE = 4;

void vertex() {
	shore_texel = VERTEX.xz * texels_per_cell;
}

// Numero de 0 a 1 fijo para cada texel y semilla. Mezclador entero como el de
// ground_silhouette.gd; el desplazamiento evita convertir negativos a uint.
float hash(ivec2 p, uint semilla) {
	uint h = uint(p.x + 1048576) * 374761393u + uint(p.y + 1048576) * 668265263u
		+ semilla * 362437u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 65535u) / 65535.0;
}

// true durante `share` de cada ciclo de `seconds`, desfasado por `phase`.
bool on(float t, float seconds, float phase, float share) {
	return fract(t / seconds + phase) < share;
}

vec3 palette(int i) {
	ivec2 p = tone_base;
	if (i == TONE_LIGHT) p = tone_light;
	if (i == TONE_DARK) p = tone_dark;
	if (i == TONE_RIPPLE) p = tone_ripple;
	if (i == TONE_SPARKLE) p = tone_sparkle;
	return texelFetch(water_texture, p, 0).rgb;
}

int classify(vec3 c) {
	int best = TONE_BASE;
	float d = 1e9;
	for (int i = 0; i < 5; i++) {
		vec3 e = c - palette(i);
		float di = dot(e, e);
		if (di < d) {
			d = di;
			best = i;
		}
	}
	return best;
}

int texel_class(ivec2 p) {
	ivec2 q = ivec2(mod(vec2(p), vec2(textureSize(water_texture, 0))));
	return classify(texelFetch(water_texture, q, 0).rgb);
}

// El fondo en p: la textura sin ondas ni destellos. Bajo una onda no se sabe que
// tono habia, asi que se toma el del vecino mas cercano que no sea onda.
int body(ivec2 p) {
	int c = texel_class(p);
	if (c < TONE_RIPPLE) return c;
	ivec2 vecinos[6] = ivec2[](ivec2(0, -1), ivec2(0, 1), ivec2(0, -2), ivec2(0, 2),
		ivec2(-1, 0), ivec2(1, 0));
	for (int k = 0; k < 6; k++) {
		int v = texel_class(p + vecinos[k]);
		if (v < TONE_RIPPLE) return v;
	}
	return TONE_BASE;
}

// true si en la capa `capa` hay una onda encendida en p.
bool ripple(ivec2 p, int capa, float t) {
	vec2 dir = capa == 0 ? vec2(1.0, 0.3) : vec2(-0.8, 0.5);
	ivec2 desfase = capa == 0 ? ivec2(0) : ivec2(53, 71);
	ivec2 q = p + desfase + ivec2(floor(dir * ripple_speed * t));
	if (texel_class(q) != TONE_RIPPLE) return false;
	// Los destellos de la textura llevan un rombo de color de onda alrededor;
	// sin su centro, que ahora pone el shader en otro sitio, quedaria hueco.
	for (int k = 0; k < 4; k++) {
		ivec2 d = ivec2(k == 0 ? 1 : (k == 1 ? -1 : 0), k == 2 ? 1 : (k == 3 ? -1 : 0));
		if (texel_class(q + d) == TONE_SPARKLE) return false;
	}
	// Los trozos van con la capa: una onda nace, deriva y se apaga entera.
	ivec2 trozo = ivec2(floor(vec2(q) / ripple_block));
	return on(t, ripple_seconds, hash(trozo, uint(11 + capa)), ripple_share);
}

// true si el texel de suelo g deja ver agua: g es agua y el rayo que baja de el
// hasta la lamina no toca tierra.
bool shows_water(ivec2 g) {
	for (int k = 0; k <= depth_texels; k++) {
		if (!is_water(g - ivec2(0, k))) return false;
	}
	return true;
}

// true si en el texel de suelo g se ve la pared de tierra del estanque.
bool shows_bank(ivec2 g) {
	return is_water(g) && !shows_water(g);
}

void fragment() {
	ivec2 t = ivec2(floor(shore_texel));
	// El rayo baja desde el suelo, en t + depth_texels, hacia el norte; la
	// primera tierra que encuentra es la pared, a la profundidad fila + 1.
	int fila = -1;
	for (int d = 1; d <= depth_texels; d++) {
		if (!is_water(t + ivec2(0, depth_texels - d))) {
			fila = d - 1;
			break;
		}
	}
	if (fila >= 0) {
		// Columna en fase con el relleno del suelo: la tesela (i, j) empieza en
		// el texel 32i - 16 y lee su pagina desde 32 * posmod(i, 4).
		int columna = int(mod(float(t.x + 16), 128.0));
		vec2 atlas = vec2(textureSize(ground_atlas, 0));
		vec2 texel = vec2(bank_page + ivec2(columna, fila)) + 0.5;
		ALBEDO = texture(ground_atlas, texel / atlas).rgb;
		// La pared mira a la camara (+Z), como la cara que era antes: la luz
		// la trata como vertical aunque se pinte sobre la lamina.
		NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	} else {
		float tiempo = floor(TIME * steps_per_second) / steps_per_second;
		// El texel de suelo por el que se ve este texel de lamina: la orilla se
		// mide ahi, que es donde se ve en pantalla.
		ivec2 g = t + ivec2(0, depth_texels);

		float ola = 6.28318 * (float(t.y) / sway_rows + tiempo / sway_seconds);
		int color = body(t + ivec2(int(round(sin(ola))), 0));
		bool bajo_pared = false;
		for (int j = 1; j <= bank_shadow_rows; j++) {
			bajo_pared = bajo_pared || shows_bank(g - ivec2(0, j));
		}
		if (bajo_pared) {
			color = color == TONE_LIGHT ? TONE_BASE : TONE_DARK;
		}
		if (ripple(t, 0, tiempo) || ripple(t, 1, tiempo)) {
			color = TONE_RIPPLE;
		}

		bool borde = !shows_water(g + ivec2(1, 0)) || !shows_water(g - ivec2(1, 0))
			|| !shows_water(g + ivec2(0, 1)) || !shows_water(g - ivec2(0, 1));
		if (borde) {
			ivec2 trozo = ivec2(floor(vec2(g) / foam_block));
			if (on(tiempo, foam_seconds, hash(trozo, 21u), foam_share)) {
				color = TONE_RIPPLE;
			}
		}

		// Un destello en t o en uno de sus cuatro vecinos; los vecinos solo
		// cuentan como punta, en la mitad central del brillo.
		ivec2 cruz[5] = ivec2[](ivec2(0), ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1),
			ivec2(0, -1));
		for (int k = 0; k < 5; k++) {
			ivec2 c = t + cruz[k];
			if (hash(c, 31u) * sparkle_every >= 1.0) continue;
			float fase = fract(tiempo / sparkle_seconds + hash(c, 32u));
			if (fase >= sparkle_share) continue;
			if (k == 0) {
				color = TONE_SPARKLE;
			} else if (abs(fase / sparkle_share - 0.5) < 0.25 && color != TONE_SPARKLE) {
				color = TONE_RIPPLE;
			}
		}
		ALBEDO = palette(color);
	}
	ROUGHNESS = 1.0;
}
