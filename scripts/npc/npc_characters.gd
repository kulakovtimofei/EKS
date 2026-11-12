class_name NpcCharacters
extends RefCounted
## Именные типажи толпы по сгенерированным референсам:
##   alt_girl        — альтушка из Румынии
##   grandpa_tweed   — элегантный сицилийский дед в твиде
##   grandpa_cap     — маленький дед в кепке с сумкой
## Вперёд — -Z. Возвращают тот же словарь, что NpcModels.human():
## {"body", "legs", "arms"} — Walker анимирует их одинаково.

const PALE := Color("f2dcd2")
const TAN := Color("c8906a")
const OLD_SKIN := Color("e8c0a8")


static func build(kind: String, root: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	match kind:
		"alt_girl": return alt_girl(root, rng)
		"grandpa_tweed": return grandpa_tweed(root, rng)
		"grandpa_cap": return grandpa_cap(root, rng)
	return NpcModels.human(root, rng)


# ---------- Альтушка ----------

static func alt_girl(root: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	if RiderSkin.available():
		return _alt_girl_skinned(root, rng)
	var leather := Color("141418")
	var jeans := Color("3c3e44")
	var knit := Color("8a8a90")
	var hair := Color("0c0c10")
	var body := _body(root, rng.randf_range(0.95, 1.02), 0.92)

	var legs: Array[Node3D] = []
	for i in 2:
		var hip := _hip(body, i, 0.09, 0.86)
		_p(hip, Vector3(0.17, 0.82, 0.18), Vector3(0, -0.4, 0), jeans)          # широкие джинсы
		_p(hip, Vector3(0.2, 0.22, 0.21), Vector3(0, -0.72, 0), jeans)          # клёш внизу
		_p(hip, Vector3(0.15, 0.13, 0.27), Vector3(0, -0.83, -0.04), leather)   # ботинок
		_p(hip, Vector3(0.16, 0.06, 0.28), Vector3(0, -0.88, -0.04), Color("222226"))  # платформа
		legs.append(hip)

	_p(body, Vector3(0.36, 0.22, 0.21), Vector3(0, 0.98, 0), knit, true)              # свитер, низ торчит
	_p(body, Vector3(0.4, 0.42, 0.25), Vector3(0, 1.2, 0), leather, true)             # короткая косуха
	_p(body, Vector3(0.04, 0.36, 0.02), Vector3(0.06, 1.2, -0.13), Color("c8ccd4"))  # молния
	_p(body, Vector3(0.1, 0.3, 0.02), Vector3(-0.08, 1.24, -0.13), leather.lightened(0.15))  # отворот
	_p(body, Vector3(0.26, 0.28, 0.12), Vector3(0, 1.2, 0.18), Color("1a1a1e"), true)  # рюкзак
	_p(body, Vector3(0.03, 0.08, 0.02), Vector3(0.06, 1.25, 0.245), Color("d0d4dc"))  # булавка

	var arms: Array[Node3D] = []
	for i in 2:
		var sh := _shoulder(body, i, 0.24, 1.37)
		_p(sh, Vector3(0.12, 0.42, 0.13), Vector3(0, -0.2, 0), leather)
		_p(sh, Vector3(0.12, 0.16, 0.12), Vector3(0, -0.47, 0), knit)          # рукав свитера на кисть
		_p(sh, Vector3(0.08, 0.06, 0.08), Vector3(0, -0.57, 0), PALE)
		arms.append(sh)

	_p(body, Vector3(0.1, 0.08, 0.1), Vector3(0, 1.45, 0), PALE)               # шея
	_p(body, Vector3(0.13, 0.025, 0.13), Vector3(0, 1.46, 0), Color("101014"))  # чокер
	var head := _p(body, Vector3(0.21, 0.25, 0.22), Vector3(0, 1.58, 0), PALE)
	# Тёмные глаза и губы
	for s in [-1.0, 1.0]:
		_p(head, Vector3(0.05, 0.025, 0.02), Vector3(0.05 * s, 0.02, -0.1), Color("101014"))
	_p(head, Vector3(0.06, 0.02, 0.02), Vector3(0, -0.07, -0.105), Color("4a1820"))
	_p(head, Vector3(0.012, 0.012, 0.012), Vector3(0.025, -0.03, -0.115), Color("d0d4dc"))  # кольцо в носу
	# Волосы: макушка, чёлка, длинные пряди до лопаток
	_p(body, Vector3(0.24, 0.12, 0.25), Vector3(0, 1.73, 0.01), hair)
	_p(body, Vector3(0.22, 0.07, 0.04), Vector3(0, 1.68, -0.115), hair)
	_p(body, Vector3(0.25, 0.5, 0.06), Vector3(0, 1.43, 0.12), hair)
	for s in [-1.0, 1.0]:
		_p(body, Vector3(0.05, 0.42, 0.12), Vector3(0.12 * s, 1.47, 0.0), hair)
		_p(body, Vector3(0.05, 0.015, 0.012), Vector3(0.06 * s, 1.7, -0.13), Color("e0e4ea"))  # заколки
	return {"body": body, "legs": legs, "arms": arms}


# ---------- Дед в твиде ----------

static func grandpa_tweed(root: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	var tweed := Color("6e665c")
	var sweater := Color("e6dcc6")
	var chino := Color("cdbd9a")
	var loafer := Color("5a3420")
	var denim := Color("4a6488")
	var hair := Color("c8b48a")
	var body := _body(root, rng.randf_range(1.02, 1.08), 0.95)

	var legs: Array[Node3D] = []
	for i in 2:
		var hip := _hip(body, i, 0.1, 0.86)
		_p(hip, Vector3(0.15, 0.82, 0.16), Vector3(0, -0.41, 0), chino)
		_p(hip, Vector3(0.13, 0.08, 0.27), Vector3(0, -0.84, -0.05), loafer)
		legs.append(hip)

	_p(body, Vector3(0.36, 0.5, 0.21), Vector3(0, 1.16, -0.005), sweater, true)      # свитер с косами
	_p(body, Vector3(0.44, 0.62, 0.25), Vector3(0, 1.14, 0.02), tweed, true)         # пиджак
	for s in [-1.0, 1.0]:
		var lapel := _p(body, Vector3(0.09, 0.32, 0.02), Vector3(0.1 * s, 1.27, -0.12), tweed.darkened(0.15))
		lapel.rotation.z = 0.25 * s
	_p(body, Vector3(0.18, 0.05, 0.16), Vector3(0, 1.43, -0.02), denim)        # воротник рубашки
	_p(body, Vector3(0.46, 0.08, 0.27), Vector3(0, 0.86, 0.02), tweed, true)         # подол пиджака

	var arms: Array[Node3D] = []
	for i in 2:
		var sh := _shoulder(body, i, 0.27, 1.38)
		_p(sh, Vector3(0.13, 0.5, 0.14), Vector3(0, -0.24, 0), tweed)
		_p(sh, Vector3(0.12, 0.05, 0.13), Vector3(0, -0.5, 0), sweater)        # манжета
		_p(sh, Vector3(0.1, 0.1, 0.1), Vector3(0, -0.57, 0), TAN)
		arms.append(sh)
	# Бутылка лимонада в правой руке и перстень
	_p(arms[1], Vector3(0.06, 0.22, 0.06), Vector3(0, -0.66, -0.04), Color("6ab0a0"))
	_p(arms[1], Vector3(0.03, 0.03, 0.03), Vector3(-0.05, -0.6, -0.02), Color("d8b040"))

	_p(body, Vector3(0.11, 0.09, 0.11), Vector3(0, 1.47, 0), TAN)
	var head := _p(body, Vector3(0.22, 0.27, 0.23), Vector3(0, 1.6, 0), TAN)
	_p(head, Vector3(0.18, 0.12, 0.1), Vector3(0, -0.08, -0.07), Color("e8e4dc"))   # седая борода
	for s in [-1.0, 1.0]:
		_p(head, Vector3(0.04, 0.02, 0.02), Vector3(0.05 * s, 0.03, -0.11), Color("3a4a5a"))
	# Зачёсанные назад волосы
	_p(body, Vector3(0.24, 0.1, 0.27), Vector3(0, 1.76, 0.02), hair)
	_p(body, Vector3(0.22, 0.14, 0.08), Vector3(0, 1.66, 0.11), hair)
	return {"body": body, "legs": legs, "arms": arms}


# ---------- Дед в кепке ----------

static func grandpa_cap(root: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	var sweater := Color("7a1e2a")
	var trousers := Color("1e2440")
	var cap := Color("e8dcb8")
	var body := _body(root, rng.randf_range(0.88, 0.94), 1.0)
	body.rotation.x = -0.12                                                    # сутулится

	var legs: Array[Node3D] = []
	for i in 2:
		var hip := _hip(body, i, 0.1, 0.88)
		_p(hip, Vector3(0.16, 0.84, 0.17), Vector3(0, -0.42, 0), trousers)
		_p(hip, Vector3(0.13, 0.09, 0.27), Vector3(0, -0.85, -0.05), Color("0e0e10"))
		legs.append(hip)

	_p(body, Vector3(0.4, 0.14, 0.24), Vector3(0, 0.92, 0), trousers, true)          # высокая талия
	_p(body, Vector3(0.42, 0.5, 0.26), Vector3(0, 1.18, 0.01), sweater, true)
	_p(body, Vector3(0.16, 0.05, 0.14), Vector3(0, 1.43, -0.03), Color("cfc8b8"))  # воротник рубашки
	var hump := _p(body, Vector3(0.36, 0.2, 0.16), Vector3(0, 1.35, 0.09), sweater, true)  # сутулая спина
	hump.rotation.x = 0.4

	var arms: Array[Node3D] = []
	for i in 2:
		var sh := _shoulder(body, i, 0.26, 1.38)
		_p(sh, Vector3(0.13, 0.52, 0.14), Vector3(0, -0.25, 0), sweater)
		_p(sh, Vector3(0.1, 0.1, 0.1), Vector3(0, -0.56, 0), OLD_SKIN)
		arms.append(sh)
	# Сумка-саквояж в левой руке
	_p(arms[0], Vector3(0.14, 0.26, 0.38), Vector3(0, -0.72, 0), Color("1a1a1e"))
	_p(arms[0], Vector3(0.145, 0.03, 0.385), Vector3(0, -0.66, 0), Color("2a6a3a"))

	_p(body, Vector3(0.1, 0.08, 0.1), Vector3(0, 1.47, -0.02), OLD_SKIN)
	var head := _p(body, Vector3(0.21, 0.25, 0.22), Vector3(0, 1.6, -0.04), OLD_SKIN)
	for s in [-1.0, 1.0]:
		_p(head, Vector3(0.03, 0.09, 0.06), Vector3(0.115 * s, 0.0, 0.01), OLD_SKIN)   # большие уши
		_p(head, Vector3(0.035, 0.015, 0.02), Vector3(0.05 * s, 0.02, -0.11), Color("2a2a30"))
	_p(head, Vector3(0.05, 0.06, 0.05), Vector3(0, -0.02, -0.12), OLD_SKIN.darkened(0.05))  # нос
	# Кепка с козырьком
	_p(body, Vector3(0.24, 0.1, 0.25), Vector3(0, 1.73, -0.04), cap)
	_p(body, Vector3(0.2, 0.02, 0.12), Vector3(0, 1.69, -0.2), cap.darkened(0.1))
	return {"body": body, "legs": legs, "arms": arms}


## Альтушка из GLB: пивоты — пустые узлы, Walker их качает, RiderSkin переносит на кости.
static func _alt_girl_skinned(root: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	var body := Node3D.new()
	root.add_child(body)
	var legs: Array[Node3D] = []
	var arms: Array[Node3D] = []
	for i in 2:
		var h := Node3D.new()
		body.add_child(h)
		legs.append(h)
		var s := Node3D.new()
		body.add_child(s)
		arms.append(s)
	var skin := RiderSkin.new()
	skin.pose_anim = ""
	skin.legs = legs
	skin.arms = arms
	skin.bend_knees = true
	skin.arm_down = 0.55
	skin.rotation.y = PI          # модель смотрит в +Z
	var k := rng.randf_range(0.95, 1.03)
	skin.scale = Vector3(k, k, k)
	body.add_child(skin)
	return {"body": body, "legs": legs, "arms": arms}


# ---------- Каркас ----------

static func _body(root: Node3D, height: float, width: float) -> Node3D:
	var body := Node3D.new()
	body.scale = Vector3(width, height, width)
	root.add_child(body)
	return body


static func _hip(body: Node3D, i: int, spread: float, y: float) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(-spread if i == 0 else spread, y, 0)
	body.add_child(hip)
	return hip


static func _shoulder(body: Node3D, i: int, spread: float, y: float) -> Node3D:
	var sh := Node3D.new()
	spread *= 0.88
	sh.position = Vector3(-spread if i == 0 else spread, y, 0)
	sh.rotation.z = 0.06 if i == 0 else -0.06
	body.add_child(sh)
	return sh


static func _p(parent: Node3D, size: Vector3, pos: Vector3, color: Color, boxy := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if boxy:
		var b := BoxMesh.new()
		b.size = size
		mi.mesh = b
	else:
		mi.mesh = Shapes.rounded(size)
	mi.material_override = Psx.color(color)
	mi.position = pos
	parent.add_child(mi)
	return mi
