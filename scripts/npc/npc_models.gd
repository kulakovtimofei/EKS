class_name NpcModels
extends RefCounted
## Низкополигональные NPC: прохожие, курьеры «Хвать», конная полиция,
## машины. Возвращают словарь с узлами для анимации.

const SKINS := [Color("f0c8a0"), Color("e0a07a"), Color("b47850"), Color("7a4a2c"), Color("ffd8b8")]
const HAIR := [Color("1a1410"), Color("4a2a14"), Color("c89a50"), Color("8a8a8a"), Color("a03018")]
const TOPS := [Color("c83c3c"), Color("3c6ec8"), Color("e8e0d0"), Color("3c8c4a"), Color("8a4ab4"), Color("e8a030"), Color("2a2a30"), Color("e86aa0")]
const BOTTOMS := [Color("27305a"), Color("3a3a40"), Color("6a5a40"), Color("1a1a1e"), Color("4a6a8a")]

# Фирменные цвета вымышленной службы доставки «Хвать»
const KHVAT_ORANGE := Color("ff6a1a")
const KHVAT_PURPLE := Color("5a2a9a")


static func human(root: Node3D, rng: RandomNumberGenerator, top := Color(0, 0, 0, 0), bottom := Color(0, 0, 0, 0)) -> Dictionary:
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	if top.a == 0.0:
		top = TOPS[rng.randi() % TOPS.size()]
	if bottom.a == 0.0:
		bottom = BOTTOMS[rng.randi() % BOTTOMS.size()]
	var tall := rng.randf_range(0.9, 1.1)
	var body := Node3D.new()
	body.scale = Vector3(rng.randf_range(0.9, 1.15), tall, rng.randf_range(0.9, 1.1))
	root.add_child(body)

	var legs: Array[Node3D] = []
	for i in 2:
		var hip := Node3D.new()
		hip.position = Vector3(-0.1 if i == 0 else 0.1, 0.85, 0)
		body.add_child(hip)
		_box(hip, Vector3(0.15, 0.8, 0.16), Vector3(0, -0.4, 0), bottom)
		_box(hip, Vector3(0.15, 0.08, 0.26), Vector3(0, -0.82, -0.05), Color("2a2a2a"))
		legs.append(hip)
	_box(body, Vector3(0.42, 0.6, 0.24), Vector3(0, 1.15, 0), top)
	var arms: Array[Node3D] = []
	for i in 2:
		var sh := Node3D.new()
		sh.position = Vector3(-0.27 if i == 0 else 0.27, 1.4, 0)
		body.add_child(sh)
		_box(sh, Vector3(0.12, 0.55, 0.13), Vector3(0, -0.27, 0), top)
		_box(sh, Vector3(0.1, 0.1, 0.1), Vector3(0, -0.58, 0), skin)
		arms.append(sh)
	_box(body, Vector3(0.24, 0.26, 0.24), Vector3(0, 1.6, 0), skin)
	var hair_c: Color = HAIR[rng.randi() % HAIR.size()]
	_box(body, Vector3(0.26, 0.09, 0.26), Vector3(0, 1.75, 0.01), hair_c)
	if rng.randf() < 0.4:
		_box(body, Vector3(0.26, 0.2, 0.06), Vector3(0, 1.62, 0.13), hair_c)   # длинные волосы
	return {"body": body, "legs": legs, "arms": arms}


static func courier(root: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	## Курьер «Хвать» на велике с большим коробом
	var bike := Node3D.new()
	root.add_child(bike)
	_cyl(bike, 0.33, 0.05, Vector3(0, 0.33, -0.55), Color("1a1a1a"), Vector3(0, 0, PI * 0.5))
	_cyl(bike, 0.33, 0.05, Vector3(0, 0.33, 0.55), Color("1a1a1a"), Vector3(0, 0, PI * 0.5))
	_box(bike, Vector3(0.05, 0.05, 1.0), Vector3(0, 0.6, 0), KHVAT_PURPLE, Vector3(0.15, 0, 0))
	_box(bike, Vector3(0.05, 0.5, 0.05), Vector3(0, 0.6, -0.5), Color("c0c0c0"), Vector3(0.3, 0, 0))
	_box(bike, Vector3(0.5, 0.04, 0.04), Vector3(0, 0.95, -0.55), Color("1a1a1a"))
	_box(bike, Vector3(0.18, 0.05, 0.25), Vector3(0, 0.85, 0.25), Color("1a1a1a"))

	var r := human(bike, rng, KHVAT_ORANGE, Color("2a2a30"))
	var body: Node3D = r.body
	body.position = Vector3(0, -0.05, 0.25)
	body.rotation.x = -0.35
	for a in r.arms:
		(a as Node3D).rotation.x = 1.1
	# Шлем
	_box(body, Vector3(0.28, 0.12, 0.3), Vector3(0, 1.79, 0), KHVAT_ORANGE)
	# Короб с логотипом
	var box := _box(body, Vector3(0.5, 0.5, 0.42), Vector3(0, 1.3, 0.38), KHVAT_ORANGE)
	_box(body, Vector3(0.52, 0.12, 0.44), Vector3(0, 1.3, 0.38), KHVAT_PURPLE)
	var logo := Label3D.new()
	logo.text = "ХВАТЬ"
	logo.font_size = 48
	logo.pixel_size = 0.004
	logo.outline_size = 0
	logo.modulate = Color.WHITE
	logo.position = Vector3(0, 1.46, 0.595)
	logo.rotation.y = 0.0
	body.add_child(logo)
	return {"body": bike, "legs": r.legs, "arms": r.arms, "box": box}


static func police_horse(root: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	var horse := Node3D.new()
	root.add_child(horse)
	var coat: Color = [Color("5a3a22"), Color("2a1e16"), Color("8a6a4a"), Color("d8d0c0")][rng.randi() % 4]
	_box(horse, Vector3(0.6, 0.7, 1.7), Vector3(0, 1.45, 0), coat)                  # корпус
	var neck := Node3D.new()
	neck.position = Vector3(0, 1.7, -0.75)
	neck.rotation.x = -0.6
	horse.add_child(neck)
	_box(neck, Vector3(0.32, 0.9, 0.4), Vector3(0, 0.4, 0), coat)
	_box(neck, Vector3(0.3, 0.32, 0.7), Vector3(0, 0.85, -0.2), coat, Vector3(0.6, 0, 0))   # голова
	_box(neck, Vector3(0.06, 0.6, 0.12), Vector3(0, 0.45, 0.2), Color("1a1410"))    # грива
	_box(horse, Vector3(0.12, 0.7, 0.12), Vector3(0, 1.3, 0.9), Color("1a1410"), Vector3(0.4, 0, 0))  # хвост
	_box(horse, Vector3(0.64, 0.12, 0.6), Vector3(0, 1.82, 0.05), Color("2a2a5a"))  # чепрак
	var legs: Array[Node3D] = []
	for p in [Vector3(-0.2, 1.15, -0.65), Vector3(0.2, 1.15, -0.65), Vector3(-0.2, 1.15, 0.65), Vector3(0.2, 1.15, 0.65)]:
		var hip := Node3D.new()
		hip.position = p
		horse.add_child(hip)
		_box(hip, Vector3(0.14, 1.1, 0.16), Vector3(0, -0.55, 0), coat)
		_box(hip, Vector3(0.16, 0.12, 0.18), Vector3(0, -1.1, 0), Color("1a1410"))
		legs.append(hip)
	# Всадник: светоотражающая куртка, фуражка
	var r := human(horse, rng, Color("e8f020"), Color("1a1a2a"))
	var body: Node3D = r.body
	body.position = Vector3(0, 1.05, 0.05)
	(r.legs[0] as Node3D).rotation.z = -0.5
	(r.legs[1] as Node3D).rotation.z = 0.5
	_box(body, Vector3(0.43, 0.08, 0.25), Vector3(0, 1.2, 0), Color("c0c0c0"))       # полоса
	_box(body, Vector3(0.3, 0.1, 0.32), Vector3(0, 1.8, -0.02), Color("101830"))     # фуражка
	_box(body, Vector3(0.3, 0.03, 0.14), Vector3(0, 1.75, -0.2), Color("101010"))    # козырёк
	return {"body": horse, "legs": legs, "neck": neck}


static func car(root: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	var paint: Color = [Color("c8202a"), Color("2a5ac8"), Color("e8e0c8"), Color("3a8a4a"), Color("e8b020"), Color("4a4a50")][rng.randi() % 6]
	var car_node := Node3D.new()
	root.add_child(car_node)
	_box(car_node, Vector3(1.8, 0.6, 4.2), Vector3(0, 0.6, 0), paint)
	_box(car_node, Vector3(1.6, 0.55, 2.2), Vector3(0, 1.15, 0.25), paint.darkened(0.1))
	_box(car_node, Vector3(1.62, 0.4, 2.0), Vector3(0, 1.15, 0.25), Color("203040"))  # стёкла
	_box(car_node, Vector3(1.82, 0.12, 0.1), Vector3(0, 0.45, -2.11), Color("c0c0c0"))
	_box(car_node, Vector3(1.82, 0.12, 0.1), Vector3(0, 0.45, 2.11), Color("c0c0c0"))
	for x in [-0.6, 0.6]:
		_box(car_node, Vector3(0.35, 0.15, 0.05), Vector3(x, 0.7, -2.11), Color("fff8c0"), Vector3.ZERO, 2.0)
		_box(car_node, Vector3(0.3, 0.12, 0.05), Vector3(x, 0.7, 2.11), Color("ff2020"), Vector3.ZERO, 1.5)
	for p in [Vector3(-0.85, 0.32, -1.3), Vector3(0.85, 0.32, -1.3), Vector3(-0.85, 0.32, 1.3), Vector3(0.85, 0.32, 1.3)]:
		_cyl(car_node, 0.32, 0.22, p, Color("141414"), Vector3(0, 0, PI * 0.5))
	return {"body": car_node}


# ---------- Примитивы ----------

static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Shapes.rounded(size)
	mi.material_override = Psx.color(color, glow)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 16
	m.rings = 1
	m.material = Psx.color(color)
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi
