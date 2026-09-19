"""Authoring recipe for the first terminal. Run in a fresh background Blender.

Manual edits belong in terminal.blend; export_terminal.py exports that file
without rebuilding. This recipe refuses to overwrite an existing .blend.
"""
from pathlib import Path
import bpy

SOURCE = Path(__file__).resolve().parent
BLEND = SOURCE / "terminal.blend"
if BLEND.exists():
    raise RuntimeError("terminal.blend already exists; export it instead of rebuilding")

# --factory-startup creates an isolated process; only its temporary scene is cleared.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

image = bpy.data.images.load(str(SOURCE / "terminal_atlas.png"))
image.pack()
material = bpy.data.materials.new("TerminalPixelPalette")
material.use_nodes = True
material.use_backface_culling = True
nodes = material.node_tree.nodes
nodes.clear()
texture = nodes.new("ShaderNodeTexImage")
texture.name = "PixelAtlas"
texture.image = image
texture.interpolation = "Closest"
texture.extension = "EXTEND"
output = nodes.new("ShaderNodeOutputMaterial")
# Color directly into Surface is Blender's glTF-supported unlit material.
material.node_tree.links.new(texture.outputs["Color"], output.inputs["Surface"])

root = bpy.data.objects.new("TerminalVisual", None)
bpy.context.scene.collection.objects.link(root)
root["asset_revision"] = 1
root["front"] = "Godot +Z; feet at Y=0; footprint 2.1 x 1.1"

tiles = {
    "top": (0, 0, 64, 32), "drawers": (0, 32, 32, 32),
    "screen": (32, 32, 32, 24), "keyboard": (32, 56, 32, 16),
    "vents": (64, 0, 32, 32), "notebook": (0, 64, 16, 24),
    "ink": (96, 0, 4, 4), "navy": (100, 0, 4, 4),
    "blue": (104, 0, 4, 4), "steel": (108, 0, 4, 4),
    "rim": (112, 0, 4, 4), "cream_shadow": (96, 4, 4, 4),
    "cream": (100, 4, 4, 4), "highlight": (104, 4, 4, 4),
    "olive": (108, 4, 4, 4), "green": (112, 4, 4, 4),
}

def box(name, position, size, base, **faces):
    x, y, z = (n / 2 for n in size)
    points = [(-x,-y,-z), (x,-y,-z), (x,y,-z), (-x,y,-z),
              (-x,-y,z), (x,-y,z), (x,y,z), (-x,y,z)]
    vertices = []
    for px, py, pz in points:
        gx, gy, gz = px+position[0], py+position[1], pz+position[2]
        vertices.append((gx, -gz, gy))  # Godot Y-up to Blender Z-up.
    sides = ["front", "back", "top", "bottom", "right", "left"]
    indices = [(4,5,6,7), (1,0,3,2), (7,6,2,3), (0,1,5,4), (5,1,2,6), (0,4,7,3)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], indices)
    mesh.materials.append(material)
    uv = mesh.uv_layers.new(name="PixelUV")
    for polygon, side in zip(mesh.polygons, sides):
        tx, ty, tw, th = tiles[faces.get(side, base)]
        # Tiny inset prevents adjacent atlas regions leaking at a face edge.
        u0, u1 = (tx+.05)/128, (tx+tw-.05)/128
        v0, v1 = 1-(ty+th-.05)/128, 1-(ty+.05)/128
        for loop, coords in zip(polygon.loop_indices, [(u0,v0),(u1,v0),(u1,v1),(u0,v1)]):
            uv.data[loop].uv = coords
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = root
    return obj

box("Tabletop", (0,1.04,0), (2.1,.12,1.1), "blue", top="top", front="steel", bottom="navy")
box("FrontLip", (0,.966,.52), (2.1,.035,.035), "navy", top="rim")
box("RearApron", (0,.78,-.44), (1.9,.4,.08), "navy", back="blue")
for side, x in [("Left",-.94),("Right",.94)]:
    for end, z in [("Front",.43),("Back",-.43)]:
        box(side+end+"Leg", (x,.48,z), (.14,.96,.14), "navy", front="steel", left="blue", top="rim")
        box(side+end+"Foot", (x,.045,z), (.18,.09,.2), "ink", front="navy")
box("Cabinet", (.66,.55,.0), (.61,.84,.9), "blue", front="drawers", right="navy", top="steel")
box("ComputerBase", (.12,1.14,-.16), (.78,.08,.52), "cream_shadow", top="cream", front="cream")
box("MonitorBody", (.12,1.52,-.21), (.86,.66,.4), "cream_shadow", top="highlight", front="cream", right="vents", back="vents")
box("MonitorFace", (.12,1.57,.002), (.72,.47,.026), "ink", front="screen")
box("PowerLight", (.42,1.255,.002), (.035,.028,.03), "green")
box("Keyboard", (.12,1.131,.36), (.74,.06,.25), "cream_shadow", top="keyboard", front="cream")
box("Notebook", (-.66,1.122,.12), (.3,.04,.42), "navy", top="notebook")

bpy.context.scene.unit_settings.system = "METRIC"
bpy.context.scene.unit_settings.scale_length = 1.0
bpy.context.scene.view_settings.view_transform = "Standard"
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
print("AUTHORING_ASSET", BLEND, "MESHES", sum(o.type == "MESH" for o in bpy.context.scene.objects))
