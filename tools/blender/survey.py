import bpy, os, math, json
from mathutils import Vector

BASE = r"C:\Users\admin\FrostbiteWolf\Imports"
OUT = r"C:\Users\admin\FrostbiteWolf\Imports\_survey"
os.makedirs(OUT, exist_ok=True)

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

names = sorted(n for n in os.listdir(BASE) if not n.startswith("_"))
rep = {}
for i, n in enumerate(names):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(BASE, n, "model.fbx"))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = n
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me = ob.data
    vs = [v.co.copy() for v in me.vertices]
    mn = [min(c[k] for c in vs) for k in range(3)]
    mx = [max(c[k] for c in vs) for k in range(3)]
    for v in me.vertices:
        v.co.x -= (mn[0] + mx[0]) / 2
        v.co.y -= (mn[1] + mx[1]) / 2
        v.co.z -= mn[2]
    d = ob.dimensions
    s = 4.0 / max(d)
    ob.scale = (s, s, s)
    bpy.ops.object.transform_apply(scale=True)
    # where is mass concentrated along y (front/back heuristic): mean y of top-30% verts
    zs = sorted(v.co.z for v in me.vertices)
    ztop = zs[int(len(zs) * 0.7)]
    top = [v.co for v in me.vertices if v.co.z >= ztop]
    ty = sum(c.y for c in top) / max(1, len(top))
    tx = sum(c.x for c in top) / max(1, len(top))
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    rep[n] = {"tris": tris, "dims": [round(x, 2) for x in ob.dimensions], "topY": round(ty, 2), "topX": round(tx, 2), "mats": len(me.materials)}
    ob.location = ((i % 7) * 7, -(i // 7) * 8, 0)
    # label
    bpy.ops.object.text_add(location=((i % 7) * 7 - 2.5, -(i // 7) * 8 - 3.2, 0))
    t = bpy.context.active_object
    t.data.body = f"{n}"
    t.data.size = 0.7

# grid arrows: a small red cone pointing -Y next to each slot (= Roblox front after export)
mat = bpy.data.materials.new("Red"); mat.diffuse_color = (1, 0, 0, 1)
for i, n in enumerate(names):
    bpy.ops.mesh.primitive_cone_add(radius1=0.3, depth=0.9, location=((i % 7) * 7 + 2.6, -(i // 7) * 8 - 2.4, 0.3), rotation=(math.radians(90), 0, 0))
    bpy.context.active_object.data.materials.append(mat)

scn = bpy.context.scene
scn.render.engine = "BLENDER_WORKBENCH"
scn.display.shading.light = "STUDIO"
scn.display.shading.color_type = "TEXTURE"
scn.render.resolution_x = 2400
scn.render.resolution_y = 1300
cam_data = bpy.data.cameras.new("Cam"); cam_data.type = "ORTHO"; cam_data.ortho_scale = 52
cam = bpy.data.objects.new("Cam", cam_data); scn.collection.objects.link(cam)
# oblique view from the front-right (looking toward +Y and down)
cam.location = Vector((21 + 18, -8 - 40, 30))
target = Vector((21, -8, 1))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
scn.camera = cam
scn.render.filepath = os.path.join(OUT, "sheet_front.png")
bpy.ops.render.render(write_still=True)
# top-down
cam.location = Vector((21, -8, 60)); cam.rotation_euler = (0, 0, 0)
scn.render.filepath = os.path.join(OUT, "sheet_top.png")
bpy.ops.render.render(write_still=True)
with open(os.path.join(OUT, "survey.json"), "w") as f:
    json.dump(rep, f, indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "survey.blend"))
print("SURVEY_DONE")
