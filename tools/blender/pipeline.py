import bpy, os, math, json, sys
from mathutils import Vector, Matrix

BASE = r"C:\Users\admin\FrostbiteWolf\Imports"
OUT = r"C:\Users\admin\FrostbiteWolf\GameAssets\New"
os.makedirs(OUT, exist_ok=True)

# name: (rig type, yaw-fix)
SPEC = {
    "RegalLion": ("quad", True), "BoldTiger": ("quad", True), "HoneyBadger": ("quad", True), "Crocodile": ("quad", True),
    "Cerberus": ("quad", True), "Kitsune": ("quad", True), "CelestialUnicorn": ("quad", True), "Hydra": ("quad", True),
    "Chimera": ("quadwing", True), "Griffin": ("quadwing", False), "Pegasus": ("quadwing", False), "PrimordialDragon": ("quadwing", True),
    "Phoenix": ("bird", False), "InfinityPhoenix": ("bird", False), "Thunderbird": ("bird", False), "Wyvern": ("bird", False),
    "Minotaur": ("biped", False),
    "Basilisk": ("serpent", False), "Leviathan": ("serpent", False), "Kraken": ("serpent", False), "Ouroboros": ("static", False),
    # batch 2 (Meshy text-to-3d, 2026-11-20)
    "WildBoar": ("quad", True), "GiantPanda": ("quad", True), "WoollyMammoth": ("quad", True),
    "LavaSalamander": ("quad", True), "VoidStag": ("quad", True),
}
TAG = os.environ.get("PIPELINE_TAG", "")  # suffix for the report/blend so batches don't overwrite each other
only = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else []
names = [n for n in SPEC if not only or n in only]

def ramp(x, a, b):
    if a == b: return 1.0 if x >= a else 0.0
    return max(0.0, min(1.0, (x - a) / (b - a)))

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
scn = bpy.context.scene
report = {}

def import_norm(n):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(BASE, n, "model.fbx"))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in new:
        if o.type != "MESH": bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1: bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active; ob.name = n; ob.data.name = n
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob

def recenter(me):
    vs = [v.co for v in me.vertices]
    mn = [min(c[k] for c in vs) for k in range(3)]; mx = [max(c[k] for c in vs) for k in range(3)]
    for v in me.vertices:
        v.co.x -= (mn[0] + mx[0]) / 2; v.co.y -= (mn[1] + mx[1]) / 2; v.co.z -= mn[2]

FORCE_YAW = {"VoidStag": 90.0}  # models whose PCA turn exceeds the 55° safety limit (antlers/wings widen them)

def yaw_fix(ob):
    me = ob.data
    if ob.name in FORCE_YAW:
        me.transform(Matrix.Rotation(math.radians(FORCE_YAW[ob.name]), 4, "Z")); me.update()
        return FORCE_YAW[ob.name]
    zs = [v.co.z for v in me.vertices]; H = max(zs)
    pts = [(v.co.x, v.co.y) for v in me.vertices if v.co.z < 0.55 * H]
    mx = sum(p[0] for p in pts) / len(pts); my = sum(p[1] for p in pts) / len(pts)
    sxx = sum((p[0] - mx) ** 2 for p in pts); syy = sum((p[1] - my) ** 2 for p in pts); sxy = sum((p[0] - mx) * (p[1] - my) for p in pts)
    ang = 0.5 * math.atan2(2 * sxy, sxx - syy)  # principal axis angle from +X
    rot = math.pi / 2 - ang                     # rotate principal axis onto Y
    while rot > math.pi / 2: rot -= math.pi
    while rot < -math.pi / 2: rot += math.pi
    if abs(rot) > math.radians(55): return 0.0
    R = Matrix.Rotation(rot, 4, "Z")
    me.transform(R); me.update()
    return math.degrees(rot)

def bake_and_outline(ob, n):
    me = ob.data
    tris0 = sum(len(p.vertices) - 2 for p in me.polygons)
    dec = ob.modifiers.new("Decimate", "DECIMATE"); dec.ratio = min(1.0, 2500 / tris0); dec.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = ob; bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier="Decimate")
    for p in me.polygons: p.use_smooth = True
    src_uv = me.uv_layers[0].name
    nuv = me.uv_layers.new(name="GameUV"); me.uv_layers.active = nuv
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004); bpy.ops.object.mode_set(mode="OBJECT")
    for dd in nuv.data: dd.uv = (0.04 + dd.uv.x * 0.96, 0.04 + dd.uv.y * 0.96)
    base_img = None
    for m in me.materials:
        if m and m.use_nodes:
            for nd in m.node_tree.nodes:
                if nd.type == "TEX_IMAGE" and nd.image and not any(k in nd.image.name.lower() for k in ("normal", "rough", "metal")): base_img = nd.image
    if base_img is None:
        p = os.path.join(BASE, n, "model.png")
        base_img = bpy.data.images.load(p)
    img = bpy.data.images.new(n + "_Albedo", 1024, 1024, alpha=False)
    mat = bpy.data.materials.new(n + "_Mat"); mat.use_nodes = True; nt = mat.node_tree
    for nd in list(nt.nodes): nt.nodes.remove(nd)
    o = nt.nodes.new("ShaderNodeOutputMaterial"); em = nt.nodes.new("ShaderNodeEmission")
    uvn = nt.nodes.new("ShaderNodeUVMap"); uvn.uv_map = src_uv
    st = nt.nodes.new("ShaderNodeTexImage"); st.image = base_img
    nt.links.new(uvn.outputs["UV"], st.inputs["Vector"]); nt.links.new(st.outputs["Color"], em.inputs["Color"]); nt.links.new(em.outputs[0], o.inputs[0])
    tg = nt.nodes.new("ShaderNodeTexImage"); tg.image = img; nt.nodes.active = tg
    me.materials.clear(); me.materials.append(mat)
    scn.render.engine = "CYCLES"; scn.cycles.device = "CPU"; scn.cycles.samples = 4; scn.render.bake.margin = 6
    bpy.ops.object.bake(type="EMIT")
    px = list(img.pixels); W = img.size[0]
    for y in range(30):
        for x in range(30):
            k = (y * W + x) * 4; px[k:k + 4] = [0, 0, 0, 1]
    img.pixels = px
    img.filepath_raw = os.path.join(OUT, n + "_Albedo.png"); img.file_format = "PNG"; img.save()
    for nd in list(nt.nodes): nt.nodes.remove(nd)
    o = nt.nodes.new("ShaderNodeOutputMaterial"); b = nt.nodes.new("ShaderNodeBsdfPrincipled"); t = nt.nodes.new("ShaderNodeTexImage"); t.image = img
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"]); nt.links.new(b.outputs[0], o.inputs[0]); b.inputs["Roughness"].default_value = 0.6
    mat.use_backface_culling = True
    me.uv_layers.remove(me.uv_layers[src_uv])
    ob.vertex_groups.new(name="OutlineShell")
    sol = ob.modifiers.new("ToonOutline", "SOLIDIFY"); sol.thickness = 0.03; sol.offset = 1.0; sol.use_flip_normals = True; sol.use_rim = False; sol.shell_vertex_group = "OutlineShell"
    bpy.ops.object.modifier_apply(modifier="ToonOutline")
    gi = ob.vertex_groups["OutlineShell"].index
    shell = set(v.index for v in me.vertices if any(g.group == gi and g.weight > 0.5 for g in v.groups))
    uvd = me.uv_layers.active.data
    for p in me.polygons:
        if all(vi in shell for vi in p.vertices):
            for li in p.loop_indices: uvd[li].uv = (0.012, 0.012)
    ob.vertex_groups.remove(ob.vertex_groups["OutlineShell"])
    return tris0, sum(len(p.vertices) - 2 for p in me.polygons)

# ---------------- generic auto-rig ----------------
def auto_rig(ob, kind):
    me = ob.data
    vs = [v.co for v in me.vertices]
    W = max(c.x for c in vs) - min(c.x for c in vs); L = max(c.y for c in vs) - min(c.y for c in vs); H = max(c.z for c in vs)
    ymin = min(c.y for c in vs); ymax = max(c.y for c in vs)
    # weight function
    def wf(c):
        w = {}
        if kind == "static":
            return w
        winged = kind in ("quadwing", "bird")
        if winged:
            ww = ramp(abs(c.x), 0.20 * W, 0.30 * W) * ramp(c.z, 0.38 * H, 0.5 * H)
            if ww > 0 and (kind == "bird" or c.y < 0.3 * L):
                w["Wing_L" if c.x > 0 else "Wing_R"] = ww
                if ww >= 1: return w
        if kind in ("quad", "quadwing"):
            tw = ramp(c.y, ymin + 0.68 * L, ymin + 0.78 * L) * (1 - sum(w.values()))
            if tw > 0:
                t2 = ramp(c.y, ymin + 0.85 * L, ymin + 0.95 * L)
                w["Tail1"] = tw * (1 - t2); w["Tail2"] = tw * t2
                if tw >= 1: return w
            lw = ramp(c.z, 0.36 * H, 0.22 * H) * (1 - sum(w.values()))
            if lw > 0:
                front = c.y < (ymin + 0.45 * L)
                w[("Leg_F" if front else "Leg_B") + ("L" if c.x > 0 else "R")] = lw
            hw = ramp(c.y, ymin + 0.28 * L, ymin + 0.18 * L) * ramp(c.z, 0.45 * H, 0.6 * H) * (1 - sum(w.values()))
            if hw > 0: w["Head"] = hw
        elif kind == "bird":
            hw = ramp(c.z, 0.72 * H, 0.85 * H) * ramp(abs(c.x), 0.2 * W, 0.1 * W) * (1 - sum(w.values()))
            if hw > 0: w["Head"] = hw
            tw = ramp(c.z, 0.3 * H, 0.15 * H) * ramp(abs(c.x), 0.2 * W, 0.1 * W) * (1 - sum(w.values()))
            if tw > 0: w["Tail1"] = tw
        elif kind == "biped":
            lw = ramp(c.z, 0.42 * H, 0.3 * H)
            if lw > 0: w["Leg_BL" if c.x > 0 else "Leg_BR"] = lw
            aw = ramp(abs(c.x), 0.22 * W, 0.32 * W) * ramp(c.z, 0.45 * H, 0.55 * H) * (1 - sum(w.values()))
            if aw > 0: w["Arm_L" if c.x > 0 else "Arm_R"] = aw
            hw = ramp(c.z, 0.8 * H, 0.88 * H) * (1 - sum(w.values()))
            if hw > 0: w["Head"] = hw
        elif kind == "serpent":
            hw = ramp(c.z, 0.7 * H, 0.85 * H)
            if hw > 0: w["Head"] = hw
        return w
    weights = []
    names = set()
    for v in me.vertices:
        w = wf(v.co); weights.append(w); names.update(w.keys())
    # bone placement from vertex clusters
    def cluster(bn):
        pts = [me.vertices[i].co for i, w in enumerate(weights) if w.get(bn, 0) > 0.5]
        if not pts: return None
        return pts
    bones = [("Root", (0, ymin + 0.4 * L, 0.5 * H), (0, ymin + 0.6 * L, 0.5 * H), None)]
    for bn in sorted(names):
        pts = cluster(bn)
        if not pts: continue
        cx = sum(p.x for p in pts) / len(pts); cy = sum(p.y for p in pts) / len(pts)
        zt = max(p.z for p in pts); zb = min(p.z for p in pts)
        if bn.startswith("Leg") or bn.startswith("Arm"):
            bones.append((bn, (cx, cy, zt), (cx, cy, zb), "Root"))
        elif bn.startswith("Wing"):
            xs = sorted(p.x for p in pts)
            inner = xs[0] if bn == "Wing_L" else xs[-1]; outer = xs[-1] if bn == "Wing_L" else xs[0]
            bones.append((bn, (inner, cy, sum(p.z for p in pts) / len(pts)), (outer, cy, zt), "Root"))
        elif bn == "Head":
            yn = min(p.y for p in pts)
            bones.append((bn, (cx, cy + 0.15 * L * (0 if kind in ("bird", "serpent", "biped") else 1), (zt + zb) / 2), (cx, yn if kind in ("quad", "quadwing") else cy - 0.2, zt), "Root"))
        elif bn == "Tail1":
            bones.append((bn, (cx, min(p.y for p in pts), (zt + zb) / 2), (cx, cy, (zt + zb) / 2), "Root"))
        elif bn == "Tail2":
            bones.append((bn, (cx, min(p.y for p in pts), (zt + zb) / 2), (cx, max(p.y for p in pts), zt), "Tail1" if "Tail1" in names else "Root"))
    # degenerate guard
    fixed = []
    for name, h, t, par in bones:
        if (Vector(h) - Vector(t)).length < 0.05: t = (t[0], t[1], t[2] + 0.3)
        fixed.append((name, h, t, par))
    bones = fixed
    ad = bpy.data.armatures.new(ob.name + "Rig"); arm = bpy.data.objects.new(ob.name + "Rig", ad); ob.users_collection[0].objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT"); eb = ad.edit_bones
    present = set()
    for name, h, t, par in bones:
        b = eb.new(name); b.head = Vector(h); b.tail = Vector(t); present.add(name)
        if par and par in present: b.parent = eb[par]
    bpy.ops.object.mode_set(mode="OBJECT")
    G = {name: ob.vertex_groups.new(name=name) for name, *_ in bones}
    for i, w in enumerate(weights):
        w = {k: v for k, v in w.items() if k in G}
        u = sum(w.values())
        if u > 1: w = {k: v / u for k, v in w.items()}; u = 1
        if u < 1: w["Root"] = w.get("Root", 0) + 1 - u
        for k, val in w.items():
            if val > 0.001: G[k].add([i], val, "REPLACE")
    m = ob.modifiers.new("Armature", "ARMATURE"); m.object = arm; ob.parent = arm
    return arm, [b[0] for b in bones]

def export(arm, ob, n):
    bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); ob.select_set(True)
    bpy.context.view_layer.objects.active = arm
    path = os.path.join(OUT, n + ".fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"ARMATURE", "MESH"}, use_mesh_modifiers=True,
        add_leaf_bones=False, bake_anim=False, axis_forward="-Z", axis_up="Y", apply_unit_scale=True,
        mesh_smooth_type="FACE", path_mode="COPY", embed_textures=True, use_armature_deform_only=True)
    return os.path.getsize(path)

rigs = {}
for i, n in enumerate(names):
    kind, yfix = SPEC[n]
    ob = import_norm(n)
    me = ob.data
    recenter(me)
    yaw = yaw_fix(ob) if yfix else 0.0
    recenter(me)
    d = ob.dimensions; s = 4.0 / max(d); ob.scale = (s, s, s)
    bpy.context.view_layer.objects.active = ob; bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    bpy.ops.object.transform_apply(scale=True)
    t0, t1 = bake_and_outline(ob, n)
    arm, bl = auto_rig(ob, kind)
    size = export(arm, ob, n)
    rigs[n] = arm
    report[n] = {"kind": kind, "yaw": round(yaw, 1), "tris": [t0, t1], "bones": bl, "fbx": size}
    arm.location = ((i % 7) * 7, -(i // 7) * 8, 0)
    print("DONE", n, report[n], flush=True)

# posed verification render: legs/arms swing, wings up, head turned
for n, arm in rigs.items():
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        if pb.name in ("Leg_FL", "Leg_BR", "Arm_L"): pb.rotation_euler = (math.radians(35), 0, 0)
        elif pb.name in ("Leg_FR", "Leg_BL", "Arm_R", "Leg_BL"): pb.rotation_euler = (math.radians(-35), 0, 0)
        elif pb.name.startswith("Wing"): pb.rotation_euler = (0, math.radians(35 if pb.name == "Wing_L" else -35), 0)
        elif pb.name == "Head": pb.rotation_euler = (0, 0, math.radians(30))
        elif pb.name == "Tail1": pb.rotation_euler = (0, 0, math.radians(35))
bpy.context.view_layer.update()
scn.render.engine = "BLENDER_WORKBENCH"; scn.display.shading.light = "STUDIO"; scn.display.shading.color_type = "TEXTURE"
scn.render.resolution_x = 2400; scn.render.resolution_y = 1300
cam_data = bpy.data.cameras.new("Cam"); cam_data.type = "ORTHO"; cam_data.ortho_scale = 52
cam = bpy.data.objects.new("Cam", cam_data); scn.collection.objects.link(cam)
cam.location = Vector((21 + 30, -8 - 22, 22)); tgt = Vector((21, -8, 1))
cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
scn.camera = cam
scn.render.filepath = os.path.join(OUT, "_posed" + TAG + ".png")
bpy.ops.render.render(write_still=True)
with open(os.path.join(OUT, "_report" + TAG + ".json"), "w") as f: json.dump(report, f, indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "NewCreatures" + TAG + ".blend"))
print("PIPELINE_DONE")
