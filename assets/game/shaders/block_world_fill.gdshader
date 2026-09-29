// Bloque cuyo dibujo no se repite por casilla sino que sigue al mundo, como los
// rellenos de 128 del suelo: la cara superior lee un relleno de NxN texeles y
// las caras laterales un canto de N de ancho, los dos por la posicion en el
// mundo. Asi una acera de muchas losas forma el mosaico entero del relleno en
// vez de repetir la misma losa, y en el editor se ve igual que en el juego.
//
// Tiene que salir igual que un StandardMaterial3D de bloque (village_pixel.tres):
// difuso Lambert, sin especular, rugoso y las texturas con source_color.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

// Arriba del PNG es el fondo de la pantalla (-Z), igual que los rellenos del
// suelo: lo dibujado es lo que se ve desde la camara.
uniform sampler2D top_fill : source_color, filter_nearest, repeat_enable;

// La fila de arriba del PNG es la arista de arriba del bloque. Mide lo mismo
// de alto que el bloque en texeles.
uniform sampler2D side_fill : source_color, filter_nearest, repeat_enable;

uniform float texels_per_cell = 32.0;

varying vec3 world_texel;
varying vec3 world_normal;

void vertex() {
	// La escala de la celda va horneada en la transformacion del bloque
	// (tools/build_paint_library.gd) y la malla mide una celda en X y Z, asi que
	// el largo de cada eje de MODEL_MATRIX es la celda con la compensacion
	// anisotropa. Dividir por ella pasa del mundo estirado a texeles, que es
	// donde el dibujo es cuadrado. Un bloque girado ya deforma el pixel
	// (decision 014), asi que no se contempla.
	vec3 celda = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz));
	vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_texel = mundo / celda * texels_per_cell;
	world_normal = mat3(MODEL_MATRIX) * NORMAL;
}

// Texel entero del relleno, con la vuelta hecha en coma flotante: el % de
// enteros negativos no esta definido en GLSL y las casillas al oeste o al norte
// del origen tienen coordenadas negativas.
vec3 fill_texel(sampler2D fill, vec2 texel) {
	vec2 lado = vec2(textureSize(fill, 0));
	return texelFetch(fill, ivec2(mod(floor(texel), lado)), 0).rgb;
}

void fragment() {
	vec3 n = normalize(world_normal);
	if (abs(n.y) > 0.5) {
		ALBEDO = fill_texel(top_fill, world_texel.xz);
	} else {
		// La cara sur (la que se ve) corre a lo largo de X; las de los lados, a
		// lo largo de Z. La altura se cuenta desde el suelo de la planta, asi que
		// la fila 0 del canto cae en lo alto del bloque.
		float alto = float(textureSize(side_fill, 0).y);
		float fila = alto - 1.0 - floor(mod(world_texel.y, texels_per_cell));
		float largo = abs(n.z) > 0.5 ? world_texel.x : world_texel.z;
		ALBEDO = fill_texel(side_fill, vec2(largo, clamp(fila, 0.0, alto - 1.0)));
	}
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
