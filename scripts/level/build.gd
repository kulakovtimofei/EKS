class_name Build
extends RefCounted
## Строительные кирпичики для городских уровней: коробки, дома
## с фасадами, фонари, бетонные блоки, балюстрады, статуи, деревья.

const FLOOR_H := 4.5
const BAY_W := 4.0


static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, collide := true, yaw := 0.0) -> Node3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	mi.mesh = m
	if not collide:
		mi.position = pos
		mi.rotation.y = yaw
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	body.add_child(col)
	body.add_child(mi)
	parent.add_child(body)
	return body


static func cyl(parent: Node, r_bottom: float, r_top: float, h: float, pos: Vector3, mat: Material, collide := false, segments := 12) -> Node3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.bottom_radius = r_bottom
	m.top_radius = r_top
	m.height = h
	m.radial_segments = segments
	m.rings = 1
	m.material = mat
	mi.mesh = m
	if not collide:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = maxf(r_bottom, r_top)
	sh.height = h
	col.shape = sh
	body.add_child(col)
	body.add_child(mi)
	parent.add_child(body)
	return body


static func sphere(parent: Node, r: float, pos: Vector3, mat: Material, scale := Vector3.ONE, hemi := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r if hemi else r * 2.0
	m.is_hemisphere = hemi
	m.radial_segments = 12
	m.rings = 6
	m.material = mat
	mi.mesh = m
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func building(parent: Node, x0: float, x1: float, z0: float, z1: float, h: float, style := "dark") -> void:
	## Палаццо: рустованный первый этаж с арками, этажи с окнами и балконами,
	## межэтажный пояс, мощный карниз и черепичная крыша.
	var w := x1 - x0
	var d := z1 - z0
	var c := Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
	var upper := "facade_" + style
	var ground := "facade_ground_dark" if style == "dark" else "facade_ground"
	# Коллизия одним блоком
	var body := StaticBody3D.new()
	body.position = c + Vector3(0, h * 0.5, 0)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(w, h, d)
	col.shape = sh
	body.add_child(col)
	parent.add_child(body)

	box(parent, Vector3(w, FLOOR_H, d), c + Vector3(0, FLOOR_H * 0.5, 0), Psx.wall(ground, Vector2(BAY_W, FLOOR_H)), false)
	box(parent, Vector3(w, h - FLOOR_H, d), c + Vector3(0, FLOOR_H + (h - FLOOR_H) * 0.5, 0), Psx.wall(upper, Vector2(BAY_W, FLOOR_H)), false)
	var trim := Psx.mat("lime", Color.WHITE, 0.5)
	box(parent, Vector3(w + 0.3, 0.35, d + 0.3), c + Vector3(0, FLOOR_H, 0), trim, false)
	box(parent, Vector3(w + 1.0, 0.9, d + 1.0), c + Vector3(0, h + 0.2, 0), trim, false)
	box(parent, Vector3(w - 0.4, 0.4, d - 0.4), c + Vector3(0, h + 0.8, 0), Psx.mat("roof_tiles", Color.WHITE, 0.6), false)
	# Угловые рустованные пилястры
	for px in [x0, x1]:
		for pz in [z0, z1]:
			box(parent, Vector3(0.8, h, 0.8), Vector3(px, h * 0.5, pz), Psx.mat("lime", Color("e0d8c4"), 0.5), false)


static func lamp(parent: Node, pos: Vector3) -> void:
	## Кованый фонарь-канделябр с шарами, как на площади
	var iron := Psx.color(Color("3a4044"))
	var glow := Psx.color(Color("fff6dc"), 1.4)
	cyl(parent, 0.28, 0.2, 0.8, pos + Vector3(0, 0.4, 0), iron, true, 8)
	cyl(parent, 0.09, 0.07, 6.2, pos + Vector3(0, 3.5, 0), iron, false, 6)
	for i in 6:
		var a := TAU * i / 6.0
		var dir := Vector3(cos(a), 0, sin(a))
		var arm := box(parent, Vector3(0.05, 0.05, 0.8), pos + Vector3(0, 6.2, 0) + dir * 0.4, iron, false)
		arm.rotation.y = -a + PI * 0.5
		sphere(parent, 0.2, pos + Vector3(0, 6.45, 0) + dir * 0.8, glow)
	sphere(parent, 0.22, pos + Vector3(0, 7.0, 0), glow)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 6.3, 0)
	light.light_color = Color("ffe8b0")
	light.light_energy = 0.6
	light.omni_range = 9.0
	parent.add_child(light)


static func barrier(parent: Node, pos: Vector3, yaw := 0.0) -> void:
	## Бетонный блок, перекрывающий половину дороги
	var b := box(parent, Vector3(1.2, 0.9, 3.4), pos + Vector3(0, 0.45, 0), Psx.mat("concrete", Color("d8d4cc"), 0.6), true, yaw)
	var stripe := Psx.color(Color("d42a2a"))
	for k in [-1.0, 1.0]:
		var s := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(1.22, 0.18, 0.5)
		m.material = stripe
		s.mesh = m
		s.position = Vector3(0, 0.15, k * 1.2)
		b.add_child(s)


static func balustrade(parent: Node, a: Vector3, b: Vector3, statues := true) -> void:
	var d := b - a
	var length := d.length()
	var yaw := atan2(d.x, d.z)
	var mid := (a + b) * 0.5
	var body := box(parent, Vector3(0.35, 1.1, length), mid + Vector3(0, 0.55, 0), Psx.wall("balustrade", Vector2(1.6, 1.1), Color.WHITE, true), true, yaw)
	body.position.y = 0.55
	var lime := Psx.mat("lime", Color("ece6d4"), 0.6)
	var n := maxi(1, int(length / 4.0))
	for i in n + 1:
		var p := a + d * (float(i) / n)
		box(parent, Vector3(0.55, 1.3, 0.55), p + Vector3(0, 0.65, 0), lime, true)
		if statues and (i == 0 or i == n):
			statue(parent, p + Vector3(0, 1.3, 0), 0.9)
		elif i % 2 == 0:
			sphere(parent, 0.22, p + Vector3(0, 1.5, 0), lime)


static func statue(parent: Node, pos: Vector3, s := 1.0, color := Color("efeadc")) -> void:
	## Барочная статуя в драпировке — силуэт из блоков
	var m := Psx.color(color)
	box(parent, Vector3(0.5, 0.2, 0.5) * s, pos + Vector3(0, 0.1, 0) * s, m, false)
	cyl(parent, 0.3 * s, 0.18 * s, 1.1 * s, pos + Vector3(0, 0.75, 0) * s, m, false, 6)
	box(parent, Vector3(0.45, 0.35, 0.25) * s, pos + Vector3(0, 1.35, 0) * s, m, false)
	sphere(parent, 0.13 * s, pos + Vector3(0, 1.65, 0) * s, m)
	var arm := box(parent, Vector3(0.1, 0.5, 0.1) * s, pos + Vector3(0.28, 1.5, -0.1) * s, m, false)
	arm.rotation = Vector3(-0.6, 0, -0.4)


static func billboard(parent: Node, pos: Vector3, size: Vector2, tex: String) -> void:
	var two := Psx.mat(tex, Color.WHITE, 1.0, true, true)
	for i in 2:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = size
		q.center_offset = Vector3(0, size.y * 0.5, 0)
		q.material = two
		mi.mesh = q
		mi.position = pos
		mi.rotation.y = i * PI * 0.5 + 0.4
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


static func ground(parent: Node, rect: Rect2, tex: String, scale: float, y := 0.0, tint := Color.WHITE) -> void:
	## Декоративное покрытие (без коллизии), без дрожания вершин
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(rect.size.x, 0.02, rect.size.y)
	m.material = Psx.mat(tex, tint, scale, false, false, 0.0, false)
	mi.mesh = m
	mi.position = Vector3(rect.position.x + rect.size.x * 0.5, y, rect.position.y + rect.size.y * 0.5)
	parent.add_child(mi)


static func unshaded(color: Color, no_fog := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.disable_fog = no_fog
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
