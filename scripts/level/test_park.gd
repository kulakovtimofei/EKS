extends Node3D
## Тестовая площадка «Хутор»: ровная бетонная плаза посреди полей.
## Рамп нет: прыжки только олли. На плазе бордюры, лавки, низкие
## «мануал-пады» и ящики, вокруг сарай, трибуна, заборы, деревья,
## а на горизонте нарисованные горы. Всё собирается кодом.

const PLAZA := 36.0      # половина стороны бетонной площадки


func _ready() -> void:
	seed(1999)

	_environment()
	_terrain()
	_plaza_furniture()
	_farm()
	_trees()
	_photo_targets()

	var player := Scooter.new()
	player.name = "Player"
	player.position = Vector3(0, 0.3, 24)
	add_child(player)

	var cam := ChaseCamera.new()
	cam.name = "Camera"
	cam.target_path = NodePath("../Player")
	cam.position = player.position + Vector3(0, 2, 5)
	add_child(cam)
	cam.make_current()

	var hud := Hud.new()
	hud.name = "Hud"
	hud.player = player
	add_child(hud)

	var photo := PhotoMode.new()
	photo.name = "PhotoMode"
	photo.camera_path = NodePath("../Camera")
	photo.player_path = NodePath("../Player")
	add_child(photo)
	photo.set_hud(hud)
	hud.connect_photo(photo)

	Game.combo_dropped.connect(func() -> void: cam.shake(1.0))
	Game.npc_hit.connect(func(_k: String) -> void: cam.shake(1.4))

	var life := CityLife.new()
	life.name = "CityLife"
	life.walk_graph = NavGraph.new()
	life.walk_graph.add_grid([-30.0, -18.0, -6.0, 6.0, 18.0, 30.0], [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0])
	life.road_graph = NavGraph.new()
	life.road_graph.add_polyline([Vector3(1.5, 0, -90), Vector3(1.5, 0, 90)])
	life.road_graph.add_polyline([Vector3(-90, 0, 1.5), Vector3(90, 0, 1.5)])
	life.pedestrians = 50
	life.scooter_spots = [Vector3(-30, 0, -10), Vector3(30, 0, 12), Vector3(-8, 0, -30), Vector3(10, 0, 30)]
	add_child(life)


# ---------- Небо и свет ----------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color("2c4a9a")
	mat.sky_horizon_color = Color("a8b8d8")
	mat.ground_horizon_color = Color("a8b8d8")
	mat.ground_bottom_color = Color("3a4a3a")
	mat.sun_angle_max = 20.0
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a96b8")
	env.ambient_light_energy = 0.9
	# Y2K: яркое небо, сочные цвета, мягкое свечение бликов
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_intensity = 1.4
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color("9aa8c8")
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 30, 0)
	sun.light_color = Color("fff0d8")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	# Нарисованная панорама гор — цилиндр вокруг мира
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 260.0
	cyl.bottom_radius = 260.0
	cyl.height = 70.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 32
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = Tex.get_tex("mountains")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_scale = Vector3(3, 1, 1)
	m.disable_fog = true
	cyl.material = m
	ring.mesh = cyl
	ring.position.y = 25.0
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


# ---------- Земля ----------

func _terrain() -> void:
	# Поле
	_static_box(Vector3(500, 1, 500), Vector3(0, -0.53, 0), Psx.mat("grass", Color.WHITE, 0.2, false, false, 0.0, false))
	# Бетонная плаза
	_static_box(Vector3(PLAZA * 2, 1, PLAZA * 2), Vector3(0, -0.5, 0), Psx.mat("concrete", Color.WHITE, 0.25, false, false, 0.0, false))
	# Асфальтовая дорожка-«восьмёрка» по центру плазы — визуально
	_deco_box(Vector3(6, 0.02, PLAZA * 2), Vector3(0, 0.01, 0), Psx.mat("asphalt", Color.WHITE, 0.3, false, false, 0.0, false))
	_deco_box(Vector3(PLAZA * 2, 0.02, 6), Vector3(0, 0.011, 0), Psx.mat("asphalt", Color.WHITE, 0.3, false, false, 0.0, false))
	# Грунтовые тропинки в поле
	_deco_box(Vector3(5, 0.02, 120), Vector3(0, -0.02, PLAZA + 60), Psx.mat("dirt", Color.WHITE, 0.25, false, false, 0.0, false))
	_deco_box(Vector3(120, 0.02, 5), Vector3(-PLAZA - 60, -0.02, 6), Psx.mat("dirt", Color.WHITE, 0.25, false, false, 0.0, false))
	# Бордюр по периметру плазы — низкий, можно перепрыгнуть
	var curb := Psx.mat("concrete", Color("c8c8c0"), 0.5, false, false, 0.0, false)
	for s in [-1.0, 1.0]:
		_static_box(Vector3(PLAZA * 2, 0.3, 0.6), Vector3(0, 0.15, s * PLAZA), curb)
		_static_box(Vector3(0.6, 0.3, PLAZA * 2), Vector3(s * PLAZA, 0.15, 0), curb)


func _plaza_furniture() -> void:
	var concrete := Psx.mat("concrete", Color("b4b4ac"), 0.5)
	var wood := Psx.mat("wood", Color.WHITE, 0.6)
	var metal := Psx.mat("metal", Color.WHITE, 0.5)
	var coping := Psx.color(Color("d8dce4"))

	# Длинные гранитные бордюры-«ледж» — запрыгивать олли
	for p in [Vector3(-12, 0, -8), Vector3(12, 0, -8), Vector3(-12, 0, 12), Vector3(12, 0, 12)]:
		_static_box(Vector3(1.0, 0.45, 9.0), p + Vector3(0, 0.225, 0), concrete)
		_deco_box(Vector3(1.04, 0.05, 9.04), p + Vector3(0, 0.47, 0), coping)

	# Мануал-пады: широкие и низкие
	_static_box(Vector3(5, 0.22, 3), Vector3(0, 0.11, -16), concrete)
	_static_box(Vector3(3, 0.22, 6), Vector3(-22, 0.11, -22), concrete)
	_static_box(Vector3(3, 0.22, 6), Vector3(22, 0.11, 22), concrete)

	# Лавки
	for p in [Vector3(-24, 0, 4), Vector3(24, 0, -4), Vector3(-6, 0, 28), Vector3(8, 0, -28)]:
		_static_box(Vector3(3.0, 0.08, 0.6), p + Vector3(0, 0.5, 0), wood)
		_static_box(Vector3(0.12, 0.46, 0.5), p + Vector3(-1.3, 0.23, 0), metal)
		_static_box(Vector3(0.12, 0.46, 0.5), p + Vector3(1.3, 0.23, 0), metal)

	# Клумбы-«квадраты» с кустами
	for p in [Vector3(-26, 0, -26), Vector3(26, 0, -26), Vector3(-26, 0, 26), Vector3(26, 0, 26)]:
		_static_box(Vector3(4, 0.5, 4), p + Vector3(0, 0.25, 0), Psx.mat("brick", Color.WHITE, 0.5))
		_deco_box(Vector3(3.6, 0.05, 3.6), p + Vector3(0, 0.5, 0), Psx.mat("dirt", Color.WHITE, 0.5))
		_billboard(p + Vector3(0, 0.5, 0), Vector2(3.2, 2.6), "bush")

	# Деревянные ящики-поддоны
	var crate := Psx.mat("wood", Color("c8a070"), 0.8)
	for p in [Vector3(16, 0, 26), Vector3(17.3, 0, 26), Vector3(16.6, 1.0, 26), Vector3(-17, 0, -27)]:
		_static_box(Vector3(1.2, 1.0, 1.2), p + Vector3(0, 0.5, 0), crate)

	# Фонари
	for p in [Vector3(-30, 0, 0), Vector3(30, 0, 0), Vector3(0, 0, -30), Vector3(0, 0, 30)]:
		_static_box(Vector3(0.18, 5.0, 0.18), p + Vector3(0, 2.5, 0), metal)
		_deco_box(Vector3(0.9, 0.2, 0.4), p + Vector3(0, 5.0, 0), Psx.color(Color("fff2a0"), 1.5))

	# Стена с граффити
	_static_box(Vector3(14, 3.0, 0.6), Vector3(-14, 1.5, -34), Psx.mat("graffiti", Color.WHITE, 0.08))


func _farm() -> void:
	# Сарай
	var barn_pos := Vector3(-60, 0, -40)
	_static_box(Vector3(14, 7, 11), barn_pos + Vector3(0, 3.5, 0), Psx.mat("wood_red", Color.WHITE, 0.3))
	_deco_box(Vector3(4, 4.5, 0.1), barn_pos + Vector3(0, 2.25, 5.55), Psx.mat("wood", Color("806040"), 0.4))
	var roof := CSGPolygon3D.new()
	roof.polygon = PackedVector2Array([Vector2(-7.8, 0), Vector2(7.8, 0), Vector2(0, 4.5)])
	roof.depth = 12.0
	roof.material = Psx.mat("roof", Color.WHITE, 0.4)
	roof.use_collision = true
	roof.position = barn_pos + Vector3(0, 7, 6)
	add_child(roof)

	# Силосная башня
	var silo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.6
	cm.bottom_radius = 2.6
	cm.height = 13.0
	cm.radial_segments = 10
	cm.material = Psx.mat("metal", Color("d0d4d8"), 0.4)
	silo.mesh = cm
	silo.position = barn_pos + Vector3(11, 6.5, -2)
	add_child(silo)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.6
	sm.height = 2.6
	sm.is_hemisphere = true
	sm.radial_segments = 10
	sm.rings = 3
	sm.material = Psx.mat("roof", Color.WHITE, 0.4)
	dome.mesh = sm
	dome.position = barn_pos + Vector3(11, 13, -2)
	add_child(dome)

	# Трибуна у плазы
	var bl := Psx.mat("metal", Color("a8b0c0"), 0.5)
	for i in 5:
		_static_box(Vector3(18, 0.4, 1.2), Vector3(0, 0.2 + i * 0.5, -PLAZA - 3 - i * 1.2), bl)
		_static_box(Vector3(18, 0.15, 0.2), Vector3(0, 0.55 + i * 0.5, -PLAZA - 3.5 - i * 1.2), Psx.mat("wood", Color.WHITE, 0.6))

	# Заборы вдоль тропинок
	_fence(Vector3(-4, 0, PLAZA + 4), Vector3(-4, 0, PLAZA + 110))
	_fence(Vector3(4, 0, PLAZA + 4), Vector3(4, 0, PLAZA + 110))
	_fence(Vector3(-PLAZA - 4, 0, 10), Vector3(-PLAZA - 110, 0, 10))
	_fence(Vector3(PLAZA + 6, 0, -PLAZA), Vector3(PLAZA + 6, 0, PLAZA))

	# Тюки сена
	var hay := Psx.mat("dirt", Color("e8c870"), 0.6)
	for p in [Vector3(-46, 0, -24), Vector3(-44, 0, -24), Vector3(-45, 1.2, -24), Vector3(50, 0, 30)]:
		var b := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.7
		c.bottom_radius = 0.7
		c.height = 1.3
		c.radial_segments = 8
		c.material = hay
		b.mesh = c
		b.rotation.z = PI * 0.5
		b.position = p + Vector3(0, 0.7, 0)
		add_child(b)


func _fence(a: Vector3, b: Vector3) -> void:
	var wood := Psx.mat("wood", Color("b0a090"), 0.6)
	var dir := b - a
	var length := dir.length()
	var n := int(length / 3.0)
	var yaw := atan2(dir.x, dir.z)
	for i in n + 1:
		var p := a + dir * (float(i) / n)
		_deco_box(Vector3(0.15, 1.3, 0.15), p + Vector3(0, 0.65, 0), wood)
	for h in [0.5, 1.05]:
		var rail := _deco_box(Vector3(0.08, 0.14, length), (a + b) * 0.5 + Vector3(0, h, 0), wood)
		rail.rotation.y = yaw


func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var placed := 0
	while placed < 70:
		var p := Vector3(rng.randf_range(-160, 160), 0, rng.randf_range(-160, 160))
		if absf(p.x) < PLAZA + 8 and absf(p.z) < PLAZA + 8:
			continue
		if absf(p.x) < 8 and p.z > 0:         # тропинка
			continue
		var s := rng.randf_range(0.8, 1.5)
		_billboard(p, Vector2(6, 7.5) * s, "canopy")
		placed += 1
	# Несколько деревьев прямо у плазы — для глубины кадра
	for p in [Vector3(-42, 0, 20), Vector3(44, 0, -14), Vector3(-40, 0, -14), Vector3(42, 0, 40)]:
		_billboard(p, Vector2(7, 8.5), "canopy")


func _billboard(pos: Vector3, size: Vector2, tex: String) -> void:
	## «Крест» из двух плоскостей — как деревья в старых играх
	var mat := Psx.mat(tex, Color.WHITE, 1.0, true, true)
	for i in 2:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = size
		q.center_offset = Vector3(0, size.y * 0.5, 0)
		q.material = _two_sided(mat)
		mi.mesh = q
		mi.position = pos
		mi.rotation.y = i * PI * 0.5 + 0.4
		add_child(mi)


var _two_sided_cache := {}

func _two_sided(m: Material) -> Material:
	return m   # материалы с вырезом уже двусторонние


func _photo_targets() -> void:
	# Позиция, подпись, очки, радиус, цвет
	var spots := [
		[Vector3(-6, 0.3, -6), "Голубь-панк", 400, 0.35, Color("8a8a96")],
		[Vector3(-60, 12.5, -40), "Корова на крыше сарая", 1200, 1.2, Color("f4f4f4")],
		[Vector3(-14, 3.6, -34), "Граффити-гоблин", 600, 1.0, Color("39ff14")],
		[Vector3(30, 18.0, -70), "НЛО над полем", 1500, 2.2, Color("00e5ff")],
		[Vector3(0, 3.0, -41), "Фанат на трибуне", 500, 0.6, Color("ffe600")],
		[Vector3(-49, 15.0, -42), "Аист на силосе", 900, 0.8, Color("ffffff")],
		[Vector3(55, 9.0, 40), "Воздушный шар", 1000, 3.0, Color("ff6a00")],
	]
	for s in spots:
		var root := Node3D.new()
		root.position = s[0]
		add_child(root)
		var mi := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = s[3]
		m.height = s[3] * 2.0
		m.radial_segments = 8
		m.rings = 5
		m.material = Psx.color(s[4], 0.6)
		mi.mesh = m
		root.add_child(mi)
		var t := PhotoTarget.new()
		t.title = s[1]
		t.points = s[2]
		t.radius = s[3]
		root.add_child(t)
		var tw := create_tween().set_loops()
		tw.tween_property(mi, "position:y", 0.3, 1.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(mi, "position:y", 0.0, 1.3).set_trans(Tween.TRANS_SINE)


# ---------- Хелперы ----------

func _static_box(size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	mi.mesh = m
	body.add_child(mi)
	add_child(body)
	return body


func _deco_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	mi.mesh = m
	mi.position = pos
	add_child(mi)
	return mi
