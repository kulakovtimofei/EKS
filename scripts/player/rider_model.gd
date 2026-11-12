class_name RiderModel
extends RefCounted
## Низкополигональный самокат и райдер из примитивов, в стиле PS1.
## Вперёд — это -Z. Узлы, которые анимирует Scooter:
##   deck  — дека с задним колесом, крутится вокруг стойки (хвостовой вихрь)
##   bars  — руль со стойкой и передним колесом (пропеллер руля)
##   rider — всё тело (присед)
##   legs  — [передняя, толчковая], поворот в бедре
##   arms  — [левая, правая]

const DECK_PINK := Color("ff2bd6")
const CHROME := Color("c8ccd4")
const TIRE := Color("1c1c20")
const HUB := Color("e6e600")
const SHIRT := Color("f2f2f2")
const SHIRT_ACCENT := Color("2a4cff")
const PANTS := Color("27305a")
const SHOES := Color("d42a2a")
const SKIN := Color("e0a07a")
const HELMET := Color("18181c")
const HELMET_STRIPE := Color("ffd400")
const PADS := Color("5a6070")


static func build(root: Node3D) -> Dictionary:
	var sc := build_scooter(root)
	var deck: Node3D = sc.deck
	var bars: Node3D = sc.bars
	return _build_rider(root, deck, bars)


static func build_scooter(root: Node3D, deck_color := DECK_PINK) -> Dictionary:
	var deck := Node3D.new()
	deck.name = "Deck"
	deck.position = Vector3(0, 0, -0.33)    # ось вращения — у стойки
	root.add_child(deck)
	_box(deck, Vector3(0.17, 0.045, 0.64), Vector3(0, 0.13, 0.36), deck_color).material_override = Psx.pearl(deck_color)
	_box(deck, Vector3(0.13, 0.07, 0.4), Vector3(0, 0.08, 0.34), Color("2a2a30"))           # батарея под декой
	_box(deck, Vector3(0.15, 0.012, 0.58), Vector3(0, 0.158, 0.36), Color("222226"))    # шкурка
	_box(deck, Vector3(0.14, 0.03, 0.16), Vector3(0, 0.2, 0.72), CHROME, Vector3(-0.5, 0, 0))  # крыло-тормоз
	_wheel(deck, Vector3(0, 0.1, 0.66))
	_box(deck, Vector3(0.12, 0.08, 0.1), Vector3(0, 0.14, 0.05), CHROME)                 # шея-кламп

	var bars := Node3D.new()
	bars.name = "Bars"
	bars.position = Vector3(0, 0, -0.36)
	root.add_child(bars)
	_cyl(bars, 0.024, 0.98, Vector3(0, 0.6, 0.0), CHROME, Vector3(0.1, 0, 0))            # стойка
	_cyl(bars, 0.022, 0.56, Vector3(0, 1.08, 0.05), CHROME, Vector3(0, 0, PI * 0.5))     # руль
	_cyl(bars, 0.03, 0.11, Vector3(-0.25, 1.08, 0.05), TIRE, Vector3(0, 0, PI * 0.5))    # грипсы
	_cyl(bars, 0.03, 0.11, Vector3(0.25, 1.08, 0.05), TIRE, Vector3(0, 0, PI * 0.5))
	_box(bars, Vector3(0.11, 0.2, 0.04), Vector3(0, 0.16, 0.0), CHROME)                  # вилка
	_wheel(bars, Vector3(0, 0.1, 0.0))
	_box(bars, Vector3(0.08, 0.05, 0.06), Vector3(0, 1.12, 0.0), Color("101014"))        # дисплей
	return {"deck": deck, "bars": bars}


static func _build_rider(root: Node3D, deck: Node3D, bars: Node3D) -> Dictionary:
	# ---- Райдер ----
	var rider := Node3D.new()
	rider.name = "Rider"
	root.add_child(rider)

	if RiderSkin.available():
		return _build_skinned(rider, deck, bars)

	var legs: Array[Node3D] = []
	for i in 2:
		var hip := Node3D.new()
		hip.position = Vector3(-0.09 if i == 0 else 0.09, 0.98, -0.02 if i == 0 else 0.1)
		rider.add_child(hip)
		_box(hip, Vector3(0.14, 0.44, 0.15), Vector3(0, -0.2, 0), PANTS)               # бедро
		_box(hip, Vector3(0.13, 0.08, 0.15), Vector3(0, -0.44, -0.02), PADS)           # наколенник
		_box(hip, Vector3(0.12, 0.38, 0.13), Vector3(0, -0.62, 0.0), PANTS)            # голень
		_box(hip, Vector3(0.13, 0.08, 0.26), Vector3(0, -0.8, -0.05), SHOES)           # кед
		_box(hip, Vector3(0.135, 0.025, 0.27), Vector3(0, -0.845, -0.05), Color.WHITE)  # подошва
		legs.append(hip)

	var torso := Node3D.new()
	torso.position = Vector3(0, 1.0, 0.03)
	torso.rotation.x = -0.28
	rider.add_child(torso)
	_box(torso, Vector3(0.36, 0.14, 0.22), Vector3(0, 0.05, 0), PANTS)                  # таз
	_box(torso, Vector3(0.4, 0.46, 0.24), Vector3(0, 0.34, 0), SHIRT)                   # корпус
	_box(torso, Vector3(0.41, 0.1, 0.245), Vector3(0, 0.3, 0), SHIRT_ACCENT)            # полоса
	_box(torso, Vector3(0.3, 0.34, 0.12), Vector3(0, 0.36, 0.17), Color("3a3a40"))      # рюкзак

	var head := Node3D.new()
	head.position = Vector3(0, 0.68, -0.04)
	head.rotation.x = 0.35
	torso.add_child(head)
	_box(head, Vector3(0.12, 0.08, 0.12), Vector3(0, -0.04, 0), SKIN)                   # шея
	_sphere(head, 0.13, Vector3(0, 0.1, 0), SKIN)
	_sphere(head, 0.16, Vector3(0, 0.15, 0.02), HELMET, Vector3(1.0, 0.9, 1.1))         # шлем
	_box(head, Vector3(0.05, 0.03, 0.34), Vector3(0, 0.29, 0.02), HELMET_STRIPE)        # полоса на шлеме
	_box(head, Vector3(0.24, 0.05, 0.08), Vector3(0, 0.15, -0.16), HELMET)              # козырёк
	_box(head, Vector3(0.2, 0.05, 0.02), Vector3(0, 0.09, -0.125), Color("101820"))     # очки

	var arms: Array[Node3D] = []
	for i in 2:
		var sh := Node3D.new()
		var side := -1.0 if i == 0 else 1.0
		sh.position = Vector3(0.24 * side, 0.52, 0.0)
		torso.add_child(sh)
		# рука тянется к грипсе: вперёд-вниз
		sh.rotation = Vector3(1.05, 0.0, 0.12 * side)
		_box(sh, Vector3(0.12, 0.28, 0.12), Vector3(0, -0.13, 0), SHIRT)                # плечо
		_box(sh, Vector3(0.12, 0.08, 0.13), Vector3(0, -0.29, 0), PADS)                 # налокотник
		_box(sh, Vector3(0.1, 0.24, 0.1), Vector3(0, -0.42, 0), SKIN)                   # предплечье
		_box(sh, Vector3(0.11, 0.1, 0.11), Vector3(0, -0.57, 0), Color("2a2a30"))       # перчатка
		arms.append(sh)

	return {"deck": deck, "bars": bars, "rider": rider, "legs": legs, "arms": arms}


## Райдер из GLB-модели. Пивоты legs/arms остаются пустыми узлами:
## Scooter их крутит, RiderSkin переносит повороты на кости.
static func _build_skinned(rider: Node3D, deck: Node3D, bars: Node3D) -> Dictionary:
	var legs: Array[Node3D] = []
	for i in 2:
		var hip := Node3D.new()
		hip.name = "LegPivot%d" % i
		rider.add_child(hip)
		legs.append(hip)
	var arms: Array[Node3D] = []
	for i in 2:
		var sh := Node3D.new()
		sh.name = "ArmPivot%d" % i
		rider.add_child(sh)
		arms.append(sh)
	var skin := RiderSkin.new()
	skin.name = "Skin"
	skin.legs = legs
	skin.position = Vector3(0, 0.165, 0)
	skin.rotation.y = PI   # модель смотрит в +Z, вперёд у самоката — -Z
	rider.add_child(skin)
	return {"deck": deck, "bars": bars, "rider": rider, "legs": legs, "arms": arms}


# ---------- Примитивы ----------

static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Psx.chrome() if color == CHROME else Psx.color(color)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return _add(parent, Shapes.rounded(size), pos, rot, color)


static func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 16
	m.rings = 1
	return _add(parent, m, pos, rot, color)


static func _sphere(parent: Node3D, r: float, pos: Vector3, color: Color, scale := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 10
	var mi := _add(parent, m, pos, Vector3.ZERO, color)
	mi.scale = scale
	return mi


static func _wheel(parent: Node3D, pos: Vector3) -> void:
	_cyl(parent, 0.1, 0.045, pos, TIRE, Vector3(0, 0, PI * 0.5))
	_cyl(parent, 0.055, 0.055, pos, HUB, Vector3(0, 0, PI * 0.5))
