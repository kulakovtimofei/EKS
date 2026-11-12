"""
Альтушка — низкополигональная модель в стиле PS2 (~2000 треугольников).
Запуск (без окна):
  blender --background --factory-startup --python tools/blender/alt_girl.py -- <папка_проекта>
Результат:
  assets/characters/alt_girl.glb      — модель для Godot
  assets/characters/alt_girl_*.png    — текстуры (лицо, деним, вязка, кожа)
  assets/characters/alt_girl_preview.png — рендер-превью
Модель собрана из частей с точками вращения в суставах:
  Body (торс, голова, волосы), LegL, LegR (в бедре), ArmL, ArmR (в плече).
Игра анимирует их поворотом, как остальных NPC. Перед: -Y (Blender).
"""
import bpy
import bmesh
import math
import os
import sys
import numpy as np

ROOT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
OUT = os.path.join(ROOT, "assets", "characters")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- сцена
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------------------------------------------------------------- текстуры
def save_image(name, rgba):
    h, w, _ = rgba.shape
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(np.flipud(rgba).astype(np.float32).ravel())
    path = os.path.join(OUT, name + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


def noise(h, w, seed, scale=1.0):
    rng = np.random.default_rng(seed)
    n = rng.random((h, w))
    # сглаживаем — «фото-текстура» низкого разрешения
    for _ in range(2):
        n = (n + np.roll(n, 1, 0) + np.roll(n, 1, 1) + np.roll(n, -1, 0) + np.roll(n, -1, 1)) / 5.0
    return (n - n.mean()) * scale


def tex_denim():
    h = w = 64
    base = np.array([0.20, 0.21, 0.24])
    yy, xx = np.mgrid[0:h, 0:w]
    twill = ((xx + yy) % 4 < 2) * 0.025
    wash = noise(h, w, 1, 0.6)
    img = np.zeros((h, w, 4))
    for c in range(3):
        img[..., c] = base[c] + twill + wash * 0.25
    # потёртости на коленях: светлое пятно в середине тайла
    knee = np.exp(-(((xx - 32) / 14.0) ** 2 + ((yy - 30) / 18.0) ** 2)) * 0.07
    img[..., :3] += knee[..., None]
    img[..., 3] = 1
    return np.clip(img, 0, 1)


def tex_knit():
    h = w = 32
    yy, xx = np.mgrid[0:h, 0:w]
    rib = (np.sin(xx * math.pi / 2.0) * 0.5 + 0.5) * 0.06
    img = np.zeros((h, w, 4))
    img[..., :3] = 0.42 + rib[..., None] + noise(h, w, 2, 0.4)[..., None] * 0.2
    img[..., 3] = 1
    return np.clip(img, 0, 1)


def tex_leather():
    h = w = 64
    n = noise(h, w, 3, 1.0)
    img = np.zeros((h, w, 4))
    img[..., :3] = 0.055 + n[..., None] * 0.08
    # складки-блики по диагонали
    yy, xx = np.mgrid[0:h, 0:w]
    crease = (np.sin((xx * 0.3 + yy * 0.15)) > 0.92) * 0.06
    img[..., :3] += crease[..., None]
    img[..., 3] = 1
    return np.clip(img, 0, 1)


def ellipse(xx, yy, cx, cy, rx, ry):
    return ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2


def tex_face():
    """Лицо 128×128: бледная кожа, смоки-айс, тёмные губы, брови."""
    s = 128
    yy, xx = np.mgrid[0:s, 0:s].astype(float)
    yy = s - 1 - yy                                      # y снизу вверх как UV
    img = np.zeros((s, s, 4))
    skin = np.array([0.93, 0.84, 0.80])
    img[..., :3] = skin + noise(s, s, 4, 0.3)[..., None] * 0.05
    img[..., 3] = 1
    # тень по краям лица и под скулами
    edge = np.clip((np.abs(xx - 64) - 34) / 30.0, 0, 1)
    img[..., :3] *= (1 - edge * 0.25)[..., None]
    for sx in (-1, 1):
        cx = 64 + sx * 23
        cy = 70
        smoky = np.clip(1.0 - ellipse(xx, yy, cx, cy, 17, 11), 0, 1)
        img[..., :3] = img[..., :3] * (1 - 0.75 * smoky[..., None]) + np.array([0.12, 0.09, 0.11]) * 0.75 * smoky[..., None]
        white = ellipse(xx, yy, cx, cy, 8.5, 4.2) < 1
        img[white, :3] = [0.85, 0.83, 0.82]
        iris = ellipse(xx, yy, cx + sx * 0.5, cy, 4.0, 4.0) < 1
        img[iris, :3] = [0.42, 0.46, 0.50]
        pupil = ellipse(xx, yy, cx + sx * 0.5, cy, 1.8, 1.8) < 1
        img[pupil, :3] = [0.05, 0.05, 0.06]
        lash = (ellipse(xx, yy, cx, cy + 2.5, 10, 4.5) < 1) & (yy > cy + 2.0)
        img[lash, :3] = [0.04, 0.03, 0.04]
        brow = (ellipse(xx, yy, cx, cy + 14, 11, 2.2) < 1)
        img[brow, :3] = [0.10, 0.08, 0.08]
    # нос — мягкая тень
    nose = np.clip(1 - ellipse(xx, yy, 64, 52, 5, 10), 0, 1) * 0.08
    img[..., :3] -= nose[..., None]
    # губы — тёмная слива
    lips = ellipse(xx, yy, 64, 34, 13, 4.5) < 1
    img[lips, :3] = [0.32, 0.12, 0.16]
    mid = (np.abs(yy - 34) < 0.7) & (np.abs(xx - 64) < 11)
    img[mid, :3] = [0.18, 0.06, 0.08]
    # колечко в носу
    ring = (np.abs(ellipse(xx, yy, 70, 46, 2.2, 2.2) - 1) < 0.6)
    img[ring, :3] = [0.85, 0.86, 0.9]
    return np.clip(img, 0, 1)


IMG = {
    "denim": save_image("alt_girl_denim", tex_denim()),
    "knit": save_image("alt_girl_knit", tex_knit()),
    "leather": save_image("alt_girl_leather", tex_leather()),
    "face": save_image("alt_girl_face", tex_face()),
}


# ---------------------------------------------------------------- материалы
def material(name, color, rough=0.6, image=None, metal=0.0):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if image is not None:
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = image
        tn.interpolation = "Closest"                    # пиксели PS2
        nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    m.diffuse_color = (*color, 1.0)
    return m


MAT = {
    "skin": material("Skin", (0.93, 0.84, 0.80), 0.55),
    "face": material("Face", (1, 1, 1), 0.55, IMG["face"]),
    "hair": material("Hair", (0.02, 0.02, 0.025), 0.35),
    "leather": material("Leather", (1, 1, 1), 0.3, IMG["leather"]),
    "knit": material("Knit", (1, 1, 1), 0.9, IMG["knit"]),
    "denim": material("Denim", (1, 1, 1), 0.8, IMG["denim"]),
    "boot": material("Boot", (0.03, 0.03, 0.035), 0.3),
    "sole": material("Sole", (0.09, 0.09, 0.1), 0.7),
    "silver": material("Silver", (0.85, 0.86, 0.9), 0.2, metal=1.0),
    "pack": material("Backpack", (0.06, 0.06, 0.07), 0.5),
}


# ---------------------------------------------------------------- геометрия
class Part:
    """Набор кусков, которые сольются в один объект с точкой вращения pivot."""

    def __init__(self, name, pivot):
        self.name = name
        self.pivot = pivot
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.mats = []

    def _mat_index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _add(self, tmp, mat, loc, rot, uv_mode, uv_scale, smooth):
        """tmp — временный bmesh куска в локальных координатах (центр в 0)."""
        if rot:
            bmesh.ops.rotate(tmp, verts=tmp.verts, cent=(0, 0, 0),
                             matrix=__import__("mathutils").Euler(rot).to_matrix())
        bmesh.ops.translate(tmp, verts=tmp.verts, vec=loc)
        uvl = tmp.loops.layers.uv.verify()
        tmp.normal_update()
        for f in tmp.faces:
            for l in f.loops:
                co = l.vert.co
                if uv_mode == "face":
                    # фронтальная проекция головы: u по X, v по Z
                    u = (co.x - loc[0]) / uv_scale[0] + 0.5
                    v = (co.z - loc[2]) / uv_scale[1] + 0.5
                else:
                    n = f.normal
                    ax = max(range(3), key=lambda i: abs(n[i]))
                    if ax == 0:
                        u, v = co.y, co.z
                    elif ax == 1:
                        u, v = co.x, co.z
                    else:
                        u, v = co.x, co.y
                    u *= uv_scale
                    v *= uv_scale
                l[uvl].uv = (u, v)
            f.smooth = smooth
            f.material_index = self._mat_index(mat)
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        # переносим в общий bmesh части со смещением на -pivot
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def box(self, size, loc, mat, rot=None, taper=1.0, uv_scale=2.0, smooth=False):
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        for v in t.verts:
            k = taper if v.co.z > 0 else 1.0                # сужение кверху
            v.co.x *= size[0] * k
            v.co.y *= size[1] * (0.5 + 0.5 * k)
            v.co.z *= size[2]
        self._add(t, mat, self._rel(loc), rot, "planar", uv_scale, smooth)

    def cyl(self, r_bottom, r_top, depth, loc, mat, seg=6, rot=None, uv_scale=2.0, smooth=False):
        t = bmesh.new()
        bmesh.ops.create_cone(t, cap_ends=True, cap_tris=False, segments=seg,
                              radius1=r_bottom, radius2=r_top, depth=depth)
        self._add(t, mat, self._rel(loc), rot, "planar", uv_scale, smooth)

    def ellipsoid(self, radii, loc, mat, seg=8, rings=6, face_uv=False, cut=None, smooth=True):
        t = bmesh.new()
        bmesh.ops.create_uvsphere(t, u_segments=seg, v_segments=rings, radius=1.0)
        for v in t.verts:
            v.co.x *= radii[0]
            v.co.y *= radii[1]
            v.co.z *= radii[2]
        if cut:
            bmesh.ops.delete(t, geom=[v for v in t.verts if cut(v.co)], context="VERTS")
        mode = "face" if face_uv else "planar"
        scale = (radii[0] * 2.0, radii[2] * 2.0) if face_uv else 2.0
        self._add(t, mat, self._rel(loc), None, mode, scale, smooth)

    def _rel(self, loc):
        return (loc[0] - self.pivot[0], loc[1] - self.pivot[1], loc[2] - self.pivot[2])

    def build(self, parent=None):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        scene.collection.objects.link(ob)
        ob.location = self.pivot
        if parent:
            ob.parent = parent
            ob.location = (self.pivot[0] - parent.location[0],
                           self.pivot[1] - parent.location[1],
                           self.pivot[2] - parent.location[2])
        return ob


# ---- Тело
body = Part("Body", (0, 0, 0))
body.box((0.34, 0.2, 0.18), (0, 0, 0.96), MAT["denim"], taper=0.95)          # пояс джинсов
body.box((0.35, 0.21, 0.12), (0, 0, 1.06), MAT["knit"])                       # низ свитера
body.box((0.38, 0.22, 0.34), (0, 0, 1.25), MAT["leather"], taper=1.12)        # косуха
body.box((0.42, 0.19, 0.08), (0, 0, 1.42), MAT["leather"], taper=0.85)        # плечи
for s in (-1, 1):                                                             # отвороты
    body.box((0.07, 0.015, 0.2), (0.07 * s, -0.112, 1.31), MAT["leather"], rot=(0, 0.3 * s, 0))
body.box((0.012, 0.01, 0.26), (0.05, -0.114, 1.22), MAT["silver"])            # молния
body.box((0.1, 0.02, 0.012), (-0.1, -0.112, 1.18), MAT["silver"])             # молния кармана
body.box((0.13, 0.03, 0.16), (0, -0.105, 1.33), MAT["knit"])                  # свитер в вырезе
body.cyl(0.048, 0.044, 0.09, (0, 0, 1.475), MAT["skin"], seg=8, smooth=True)  # шея
body.cyl(0.052, 0.052, 0.022, (0, 0, 1.47), MAT["hair"], seg=8)               # чокер
body.cyl(0.054, 0.05, 0.008, (0, -0.005, 1.455), MAT["silver"], seg=8)        # цепочка
body.ellipsoid((0.096, 0.108, 0.122), (0, 0, 1.61), MAT["face"], seg=10, rings=8, face_uv=True)
# Волосы: шапка без лица, чёлка, пряди по бокам, длинный «хвост» за спиной
body.ellipsoid((0.108, 0.118, 0.118), (0, 0.01, 1.635), MAT["hair"], seg=10, rings=8,
               cut=lambda c: c.y < -0.035 and c.z < 0.05, smooth=False)
body.box((0.19, 0.035, 0.05), (0, -0.098, 1.69), MAT["hair"], taper=1.05)     # чёлка
for s in (-1, 1):
    body.box((0.04, 0.09, 0.34), (0.098 * s, -0.025, 1.5), MAT["hair"], taper=1.15, rot=(0.08, 0, 0))
    body.box((0.03, 0.006, 0.012), (0.055 * s, -0.112, 1.705), MAT["silver"], rot=(0, 0.35 * s, 0))  # заколки
    body.box((0.03, 0.006, 0.012), (0.035 * s, -0.114, 1.72), MAT["silver"], rot=(0, -0.2 * s, 0))
body.box((0.22, 0.06, 0.46), (0, 0.075, 1.42), MAT["hair"], taper=1.08)       # спина
body.box((0.24, 0.12, 0.26), (0, 0.17, 1.24), MAT["pack"], taper=0.9)         # рюкзак
body.box((0.006, 0.006, 0.07), (0.04, 0.232, 1.28), MAT["silver"], rot=(0, 0.6, 0))   # булавка
body.box((0.2, 0.01, 0.012), (0, 0.232, 1.18), MAT["silver"])                 # молния рюкзака
body_ob = body.build()

# ---- Ноги (точка вращения — бедро)
legs = []
for i, s in enumerate((-1, 1)):
    hip = (0.09 * s, 0, 0.92)
    p = Part("LegL" if s < 0 else "LegR", hip)
    p.cyl(0.115, 0.085, 0.82, (0.09 * s, 0, 0.51), MAT["denim"], seg=7)        # широкие джинсы
    p.box((0.13, 0.25, 0.12), (0.09 * s, -0.035, 0.1), MAT["boot"], taper=0.85)  # ботинок
    p.box((0.14, 0.27, 0.05), (0.09 * s, -0.035, 0.025), MAT["sole"])          # платформа
    legs.append(p.build(body_ob))

# ---- Руки (точка вращения — плечо), слегка разведены
for s in (-1, 1):
    sh = (0.205 * s, 0, 1.415)
    p = Part("ArmL" if s < 0 else "ArmR", sh)
    p.cyl(0.055, 0.068, 0.42, (0.215 * s, 0, 1.2), MAT["leather"], seg=6)
    p.cyl(0.06, 0.058, 0.14, (0.222 * s, 0, 0.94), MAT["knit"], seg=6)        # рукав свитера
    p.box((0.055, 0.085, 0.09), (0.225 * s, -0.005, 0.83), MAT["skin"], smooth=True)
    p.build(body_ob)

# ---------------------------------------------------------------- превью
for ob in bpy.data.objects:
    ob.select_set(True)

cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 55
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
cam.location = (1.7, -3.2, 1.25)
cam.rotation_euler = (math.radians(86), 0, math.radians(28))
scene.camera = cam
light_data = bpy.data.lights.new("Sun", "SUN")
light_data.energy = 3.0
light = bpy.data.objects.new("Sun", light_data)
light.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
scene.collection.objects.link(light)

scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "TEXTURE"
scene.display.shading.show_cavity = False
scene.render.resolution_x = 640
scene.render.resolution_y = 800
scene.render.film_transparent = False
world = bpy.data.worlds.new("W")
world.color = (0.45, 0.47, 0.5)
scene.world = world
scene.render.filepath = os.path.join(OUT, "alt_girl_preview.png")
bpy.ops.render.render(write_still=True)

# ---------------------------------------------------------------- экспорт
bpy.data.objects.remove(cam)
bpy.data.objects.remove(light)
tris = sum(len(p.vertices) - 2 for ob in bpy.data.objects if ob.type == "MESH" for p in ob.data.polygons)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "alt_girl.glb"), export_format="GLB",
                          export_yup=True, export_apply=True)
print("ALT_GIRL_OK triangles=%d" % tris)
