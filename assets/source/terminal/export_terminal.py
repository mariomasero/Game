"""Export the editable terminal.blend, preserving all manual source edits."""
from pathlib import Path
import sys
import bpy

source = Path(__file__).resolve().parent
project = source.parents[2]
blend = source / "terminal.blend"
destination = project / "assets/game/models/terminal.glb"
if Path(bpy.data.filepath).resolve() != blend.resolve():
    raise RuntimeError("Open terminal.blend before exporting")
destination.parent.mkdir(parents=True, exist_ok=True)
texture_destination = project / "assets/game/textures/terminal_atlas.png"
texture = bpy.data.images["terminal_atlas.png"]
if "--" in sys.argv and "--refresh-atlas" in sys.argv[sys.argv.index("--") + 1:]:
    # Explicitly opt in: a normal export must preserve texture painting in .blend.
    if not (source / "terminal_atlas.png").is_file():
        raise FileNotFoundError("Rasterize terminal_atlas.svg before refreshing")
    if texture.packed_file:
        texture.unpack(method="REMOVE")
    texture.filepath_raw = str(source / "terminal_atlas.png")
    texture.reload()
    texture.pack()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
original_path = texture.filepath_raw
try:
    texture.filepath_raw = str(texture_destination)
    texture.file_format = "PNG"
    texture.save()
finally:
    texture.filepath_raw = original_path
root = bpy.data.objects["TerminalVisual"]
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
for obj in root.children_recursive:
    obj.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=str(destination), export_format="GLB", use_selection=True,
    export_yup=True, export_animations=False, export_cameras=False,
    export_lights=False, export_extras=True, export_texcoords=True,
    export_normals=True, export_materials="EXPORT", export_image_format="AUTO",
)
print("EXPORTED", destination)
