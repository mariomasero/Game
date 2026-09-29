extends SceneTree

## Genera las dos MeshLibrary con las que se pinta el pueblo en el editor
## (docs/decisions/013-mapa-autorado-con-gridmap.md):
##
## - paint_terrain.meshlib.tres, para el GridMap "Terreno". Tres marcadores
##   planos, uno por terreno, con el MISMO nombre que GroundAtlas.TERRAIN_IDS, y
##   detras el de agua, llamado como WaterSurface.ITEM.
##   No son arte: son la brocha. Lo que se ve al final es el suelo por teselas,
##   que scenes/world/village.gd construye leyendo que marcador hay en cada celda.
## - paint_blocks.meshlib.tres, para el GridMap "Bloques". El cubo de PixZels con
##   cada material de bloque que ya existe, o una losa mas baja para los de
##   ALTO_TEXELES.
## - paint_zones.meshlib.tres, para el GridMap "Parcela"
##   (docs/decisions/014-parcela-y-camara.md). Un solo marcador, llamado como
##   PlotLayout.ITEM_PARCELA, que dice donde se pueden poner muebles.
##
##   godot --headless --path . --script tools/build_paint_library.gd
##
## Las medidas salen de VillageMetrics con DEFAULT_PITCH_DEGREES: GridMap no
## escala sus piezas a la celda, asi que la escala anisotropa tiene que ir
## horneada en la transformacion de cada item. Si algun dia cambia el angulo de
## camara, se vuelve a ejecutar esto y ya.
##
## Se puede anadir un bloque nuevo a mano desde el editor de MeshLibrary, pero se
## pierde en cuanto se vuelva a ejecutar esta herramienta: para que dure, se
## anade a BLOQUES.

const BLOCK_MESH := "res://assets/game/tilesets/grass_block.obj"

const SALIDA_TERRENO := "res://assets/game/tilesets/paint_terrain.meshlib.tres"
const SALIDA_BLOQUES := "res://assets/game/tilesets/paint_blocks.meshlib.tres"
const SALIDA_ZONAS := "res://assets/game/tilesets/paint_zones.meshlib.tres"

## Color del marcador de parcela. Amarillo, para no confundirlo con ningun
## terreno, y mas transparente que ellos porque se pinta encima.
const COLOR_PARCELA := Color(0.98, 0.82, 0.22, 0.40)

## La parcela flota un poco mas que los marcadores de terreno, para no
## parpadear contra ellos donde coinciden.
const ALTURA_PARCELA := 0.04

## Color de cada marcador de terreno, en el orden de GroundAtlas.TERRAIN_IDS.
## Semitransparentes para que el suelo de verdad se vea debajo mientras se pinta.
const COLORES_TERRENO: Array[Color] = [
	Color(0.36, 0.72, 0.30, 0.45),   # grass
	Color(0.62, 0.42, 0.24, 0.55),   # dirt
	Color(0.62, 0.62, 0.68, 0.60),   # cobblestone
]

## Marcador de agua. Un GridMap guarda ids, no nombres, asi que el id tiene que
## ser fijo: lejos de los de terreno (su posicion en TERRAIN_IDS) para que anadir
## un terreno algun dia no le quite el sitio al agua ya pintada.
const ID_AGUA := 100
const COLOR_AGUA := Color(0.25, 0.55, 0.85, 0.55)

## Cuanto flota el marcador sobre el suelo, para que no parpadee contra el.
const ALTURA_MARCADOR := 0.02

## Lado de la muestra de color de cada terreno en la paleta, en pixeles. Es un
## color liso: el editor la amplia sin perder nada y pequena ocupa poco en el .tres.
const LADO_MUESTRA := 16

## Bloques pintables: nombre del item -> material. El nombre es lo que se ve en
## la paleta del GridMap.
##
## El id de cada item es su posicion en esta tabla, y un GridMap guarda ids, no
## nombres: quitar o reordenar una entrada cambia el bloque de lo ya pintado.
## Anadir siempre al final. grass_meadow se retiro el 23 de septiembre de 2026
## (dirt paso del id 3 al 2) cuando el GridMap Bloques del pueblo estaba vacio.
const BLOQUES := {
	&"cobblestone": "res://assets/game/materials/cobblestone_pixel.tres",
	&"grass": "res://assets/game/materials/village_pixel.tres",
	&"dirt": "res://assets/game/materials/dirt_pixel.tres",
	&"summer_grass": "res://assets/game/materials/summer_grass_pixel.tres",
	&"stone_slab": "res://assets/game/materials/stone_slab_pixel.tres",
}

## Bloques que no llenan la celda: nombre -> alto en texeles. En vez del cubo de
## PixZels llevan una caja de una celda de planta y ese alto, apoyada en el suelo
## de la casilla. La losa de acera mide 8: con la compensacion de VillageMetrics
## su canto sale de 8 px en pantalla y su cara superior sube 8 px.
const ALTO_TEXELES := {
	&"stone_slab": 8,
}

func _initialize() -> void:
	var celda := VillageMetrics.block_scale(VillageMetrics.DEFAULT_PITCH_DEGREES)
	var ok := _guardar(_terreno(celda), SALIDA_TERRENO)
	ok = _guardar(_bloques(celda), SALIDA_BLOQUES) and ok
	ok = _guardar(_zonas(celda), SALIDA_ZONAS) and ok
	quit(0 if ok else 1)

func _terreno(celda: Vector3) -> MeshLibrary:
	var lib := MeshLibrary.new()
	for t in GroundAtlas.terrain_count():
		_marcador(lib, t, String(GroundAtlas.terrain_id(t)), COLORES_TERRENO[t],
			ALTURA_MARCADOR, celda)
	_marcador(lib, ID_AGUA, String(WaterSurface.ITEM), COLOR_AGUA,
		ALTURA_MARCADOR, celda)
	return lib

func _zonas(celda: Vector3) -> MeshLibrary:
	var lib := MeshLibrary.new()
	_marcador(lib, 0, String(PlotLayout.ITEM_PARCELA), COLOR_PARCELA, ALTURA_PARCELA, celda)
	return lib

## Un marcador plano de color: la brocha de un GridMap que un script lee por
## nombre de item. No es arte.
func _marcador(lib: MeshLibrary, id: int, nombre: String, color: Color,
		altura: float, celda: Vector3) -> void:
	var plano := PlaneMesh.new()
	plano.size = Vector2(celda.x, celda.z)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	plano.material = mat
	lib.create_item(id)
	lib.set_item_name(id, nombre)
	lib.set_item_mesh(id, plano)
	# GridMap pone la pieza en el CENTRO de la celda, a media altura; el
	# marcador tiene que quedar a ras de suelo, en la base de la planta 0.
	lib.set_item_mesh_transform(id, Transform3D(Basis.IDENTITY,
		Vector3(0.0, -celda.y * 0.5 + altura, 0.0)))
	lib.set_item_mesh_cast_shadow(id, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	var muestra := Image.create(LADO_MUESTRA, LADO_MUESTRA, false, Image.FORMAT_RGBA8)
	muestra.fill(Color(color, 1.0))
	lib.set_item_preview(id, ImageTexture.create_from_image(muestra))

func _bloques(celda: Vector3) -> MeshLibrary:
	var lib := MeshLibrary.new()
	var cubo: Mesh = load(BLOCK_MESH)
	var id := 0
	for nombre: StringName in BLOQUES:
		var material: Material = load(BLOQUES[nombre])
		if material == null:
			printerr("no se encuentra el material %s" % BLOQUES[nombre])
			continue
		# Copia de la malla con el material puesto en la superficie: un item de
		# MeshLibrary no tiene material propio, y village.gd lee de aqui el
		# material con que dibujar cada bloque en el juego.
		var alto: int = ALTO_TEXELES.get(nombre, VillageMetrics.TEXELS_PER_CELL)
		var malla: Mesh = cubo.duplicate() as Mesh
		if alto != VillageMetrics.TEXELS_PER_CELL:
			malla = _losa(alto)
		malla.surface_set_material(0, material)
		lib.create_item(id)
		lib.set_item_name(id, String(nombre))
		lib.set_item_mesh(id, malla)
		# GridMap pone la pieza en el centro de la celda: una losa baja hay que
		# bajarla hasta que apoye en el suelo de la casilla.
		var fraccion := float(alto) / float(VillageMetrics.TEXELS_PER_CELL)
		lib.set_item_mesh_transform(id, Transform3D(Basis.from_scale(celda),
			Vector3(0.0, -celda.y * 0.5 * (1.0 - fraccion), 0.0)))
		var miniatura := _cara_superior(material)
		if miniatura != null:
			lib.set_item_preview(id, miniatura)
		id += 1
	return lib

## Caja de una celda de planta y `alto` texeles, en unidades de celda como el
## cubo importado (su scale_mesh es un texel). No lleva UV que importe: el
## material de estos bloques lee el dibujo por la posicion en el mundo
## (block_world_fill.gdshader).
func _losa(alto: int) -> ArrayMesh:
	var caja := BoxMesh.new()
	caja.size = Vector3(1.0, float(alto) / float(VillageMetrics.TEXELS_PER_CELL), 1.0)
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, caja.get_mesh_arrays())
	return malla

## Miniatura para la paleta del GridMap. El editor las genera solo con ventana,
## asi que en --headless se recorta a mano la cara superior del atlas de bloque:
## en el reparto de PixZels vive en (33,33) y mide 32x32. Sale transpuesta, que
## para reconocer el material en la paleta da igual. Un bloque de shader da la
## primera losa de su relleno, que ya esta derecha.
func _cara_superior(material: Material) -> Texture2D:
	var shader := material as ShaderMaterial
	if shader != null:
		var relleno := shader.get_shader_parameter(&"top_fill") as Texture2D
		if relleno == null or relleno.get_image() == null:
			return null
		var lado := VillageMetrics.TEXELS_PER_CELL
		return ImageTexture.create_from_image(
			relleno.get_image().get_region(Rect2i(0, 0, lado, lado)))
	var base := material as BaseMaterial3D
	if base == null or base.albedo_texture == null:
		return null
	var atlas := base.albedo_texture.get_image()
	if atlas == null:
		return null
	return ImageTexture.create_from_image(atlas.get_region(Rect2i(33, 33, 32, 32)))

func _guardar(lib: MeshLibrary, ruta: String) -> bool:
	var err := ResourceSaver.save(lib, ruta)
	if err != OK:
		printerr("no se pudo escribir %s (error %d)" % [ruta, err])
		return false
	print("escrito %s con %d items" % [ruta, lib.get_item_list().size()])
	return true
