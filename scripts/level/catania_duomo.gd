extends Node3D
## Катания, Пьяцца дель Дуомо — стилизованная версия реальной площади.
## Оси: X — на восток, -Z — на север. Начало координат — центр площади.
##
##   север:  Палаццо дельи Элефанти (ратуша), справа уходит Виа Этнеа
##   центр:  фонтан со слоном (u Liotru) и обелиском
##   восток: собор Святой Агаты за белой балюстрадой, колокольня, купол,
##           сад Бадии; Палаццо деи Кьеричи
##   юг:     ворота Порта Узеда → Виа Дузмет, виадук с арками, море
##   юго-запад: рыбный рынок (Пескерия)
##   запад:  Виа Гарибальди
##   север-восток: Виа Витторио Эмануэле II уходит на восток
## На горизонте — Этна с дымком.

const PIAZZA := Rect2(-36, -36, 76, 84)     # x, z, ширина, глубина
const ELEPHANT := Vector3(-8, 0, -6)

var walk := NavGraph.new()
var roads := NavGraph.new()


func _ready() -> void:

	_environment()
	_ground_and_streets()
	_buildings()
	_palazzo_elefanti()
	_cathedral()
	_elephant_fountain()
	_porta_uzeda_and_seafront()
	_fish_market()
	_street_furniture()
	_roads()
	_walkways()

	var player := Scooter.new()
	player.name = "Player"
	player.position = Vector3(4, 0.3, 32)
	add_child(player)

	var cam := ChaseCamera.new()
	cam.name = "Camera"
	cam.target_path = NodePath("../Player")
	cam.position = player.position + Vector3(0, 2, 5)
	cam.far = 4000.0
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
	life.walk_graph = walk
	life.road_graph = roads
	life.scooter_spots = [
		Vector3(-30, 0, 40), Vector3(26, 0, 40), Vector3(-30, 0, -18), Vector3(12, 0, -18),
		Vector3(43, 0, -60), Vector3(-70, 0, -20), Vector3(60, 0, -20), Vector3(14, 0, 92),
		Vector3(-60, 0, 92), Vector3(-6, 0, 70),
	]
	add_child(life)

	_photo_targets()
	Game.trick_popup.emit.call_deferred("Катания · Пьяцца дель Дуомо")


# ---------- Небо, Этна, море ----------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color("1f5fe0")
	mat.sky_horizon_color = Color("bff0ff")
	mat.ground_horizon_color = Color("c8dcf0")
	mat.ground_bottom_color = Color("6a7a8a")
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9aaac8")
	env.ambient_light_energy = 0.95
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
	env.fog_light_color = Color("c0d0e4")
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Низкое тёплое солнце — как на фото: фасад собора в золоте
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, -100, 0)
	sun.light_color = Color("ffe2b0")
	sun.light_energy = 1.6
	sun.shadow_blur = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	if OS.has_feature("web"):
		# В браузере тень — второй проход по всей сцене: только ближняя зона, один каскад
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 30.0
	add_child(sun)

	# Этна: пологий конус со снежной шапкой и дымом
	var etna := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 60.0
	cone.bottom_radius = 1100.0
	cone.height = 420.0
	cone.radial_segments = 16
	cone.material = Build.unshaded(Color("6a7898"))
	etna.mesh = cone
	etna.position = Vector3(-350, 150, -1700)
	add_child(etna)
	var snow := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 58.0
	sc.bottom_radius = 220.0
	sc.height = 90.0
	sc.radial_segments = 16
	sc.material = Build.unshaded(Color("e4e8f0"))
	snow.mesh = sc
	snow.position = Vector3(-350, 316, -1700)
	add_child(snow)
	for i in 5:
		var puff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 60.0 + i * 18.0
		sm.height = sm.radius * 1.2
		sm.radial_segments = 8
		sm.rings = 4
		sm.material = Build.unshaded(Color(0.85, 0.85, 0.88, 0.55))
		puff.mesh = sm
		puff.position = Vector3(-350 + i * 70, 400 + i * 45, -1700 + i * 30)
		add_child(puff)
		var tw := create_tween().set_loops()
		tw.tween_property(puff, "position:x", puff.position.x + 40.0, 6.0 + i).set_trans(Tween.TRANS_SINE)
		tw.tween_property(puff, "position:x", puff.position.x, 6.0 + i).set_trans(Tween.TRANS_SINE)

	# Море за набережной
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 2000)
	pm.material = Build.unshaded(Color("2a5a8a"), false)
	sea.mesh = pm
	sea.position = Vector3(0, -1.5, 1110)
	add_child(sea)


# ---------- Земля ----------

func _ground_and_streets() -> void:
	# Вся земля — лавовая мостовая с одной коллизией
	var body := StaticBody3D.new()
	body.position = Vector3(0, -0.5, -40)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(360, 1, 300)
	col.shape = sh
	body.add_child(col)
	add_child(body)
	Build.ground(self, Rect2(-180, -190, 360, 300), "basolato", 0.25, -0.01)

	# Асфальт улиц
	for r in [Rect2(-180, -32, 144, 8), Rect2(40, -32, 140, 8), Rect2(32, -190, 8, 154), Rect2(18, 48, 8, 42), Rect2(-180, 90, 360, 10)]:
		Build.ground(self, r, "asphalt", 0.3, 0.0)
	# Проезд по площади — тот же камень, но темнее, как укатанная колея
	Build.ground(self, Rect2(-36, -32, 76, 8), "basolato", 0.25, 0.0, Color(0.8, 0.8, 0.82))
	Build.ground(self, Rect2(18, -24, 8, 72), "basolato", 0.25, 0.0, Color(0.8, 0.8, 0.82))
	# Тротуары из светлых плит
	for r in [Rect2(-180, -36, 144, 4), Rect2(-180, -24, 144, 4), Rect2(40, -36, 140, 4), Rect2(40, -24, 60, 3),
			Rect2(28, -190, 4, 154), Rect2(40, -190, 4, 154), Rect2(14, 48, 4, 42), Rect2(26, 48, 4, 42),
			Rect2(-180, 86, 360, 4), Rect2(-180, 100, 360, 3)]:
		Build.ground(self, r, "slab", 0.4, 0.005)

	# Невидимые стены по краям карты
	for wall in [[Vector3(0, 5, -192), Vector3(400, 10, 1)], [Vector3(0, 5, 104), Vector3(400, 10, 1)],
			[Vector3(-182, 5, -40), Vector3(1, 10, 300)], [Vector3(182, 5, -40), Vector3(1, 10, 300)]]:
		var b := StaticBody3D.new()
		b.position = wall[0]
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = wall[1]
		c.shape = s
		b.add_child(c)
		add_child(b)


# ---------- Застройка ----------

func _buildings() -> void:
	# Северо-запад, вдоль Виа Гарибальди (север)
	Build.building(self, -80, -37, -80, -36, 17, "cream")
	Build.building(self, -130, -84, -80, -36, 16, "dark")
	Build.building(self, -180, -134, -80, -36, 15, "grey")
	# Запад площади и юг Виа Гарибальди
	Build.building(self, -80, -37, -20, 46, 17, "dark")
	Build.building(self, -130, -84, -20, 46, 15, "cream")
	Build.building(self, -180, -134, -20, 46, 16, "dark")
	# Северо-восток: угол Этнеа / Витторио Эмануэле
	Build.building(self, 44, 92, -80, -36, 18, "cream")
	Build.building(self, 96, 180, -80, -36, 16, "grey")
	# Виа Этнеа, дальше на север
	Build.building(self, -36, 28, -190, -80, 18, "grey")
	Build.building(self, 44, 120, -190, -84, 17, "dark")
	# Юго-восток: Палаццо деи Кьеричи и дальше
	Build.building(self, 30, 100, 24, 86, 16, "dark")
	Build.building(self, 104, 180, -20, 86, 15, "cream")
	# Юг Дузмет, запад рынка
	Build.building(self, -80, -37, 50, 86, 14, "grey")
	Build.building(self, -180, -84, 50, 86, 13, "cream")


func _palazzo_elefanti() -> void:
	## Ратуша: тёмная лава, белые рустованные пилястры, большой портал
	var x0 := -34.0
	var x1 := 28.0
	var z := -38.0
	Build.building(self, x0, x1, -78, z, 19, "dark")
	var lime := Psx.mat("lime", Color("ece4d0"), 0.5)
	for i in 9:
		var x := lerpf(x0 + 1.0, x1 - 1.0, i / 8.0)
		Build.box(self, Vector3(1.4, 18.5, 0.6), Vector3(x, 9.25, z + 0.3), lime, false)
	# Портал с балконом
	var cx := (x0 + x1) * 0.5
	Build.box(self, Vector3(5.0, 7.0, 0.8), Vector3(cx, 3.5, z + 0.4), lime, false)
	Build.box(self, Vector3(3.2, 5.6, 0.2), Vector3(cx, 2.8, z + 0.85), Psx.color(Color("2a1e18")), false)
	Build.box(self, Vector3(7.0, 0.4, 1.6), Vector3(cx, 7.2, z + 0.8), lime, false)
	# Фронтон над порталом и часы
	var ped := CSGPolygon3D.new()
	ped.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(0, 2.6)])
	ped.depth = 0.6
	ped.material = lime
	ped.position = Vector3(cx, 19.6, z + 0.6)
	add_child(ped)
	var clock := Build.cyl(self, 1.1, 1.1, 0.2, Vector3(cx, 17.0, z + 0.7), Psx.color(Color("f4f0e0")), false, 12)
	clock.rotation.x = PI * 0.5


func _cathedral() -> void:
	## Собор Святой Агаты: трёхъярусный барочный фасад из светлого
	## известняка с гранитными колоннами, нефы, купол, колокольня.
	var cream := Psx.mat("lime", Color("f2e4c0"), 0.15)
	var granite := Psx.color(Color("6a6a70"))
	var dark := Psx.color(Color("241c18"))
	var fx := 41.0                                  # плоскость фасада

	# Неф и боковые стены
	Build.box(self, Vector3(58, 22, 26), Vector3(fx + 31, 11, 0), Psx.wall("cathedral", Vector2(6, 8)), true)
	# Ярус 1
	Build.box(self, Vector3(3, 13, 32), Vector3(fx + 1.5, 6.5, 0), cream, true)
	for z in [-14.0, -10.0, -6.0, 6.0, 10.0, 14.0]:
		Build.cyl(self, 0.55, 0.5, 11.5, Vector3(fx - 0.6, 5.75, z), granite, true, 10)
		Build.box(self, Vector3(1.4, 0.6, 1.4), Vector3(fx - 0.6, 11.8, z), cream, false)
	Build.box(self, Vector3(4.2, 1.2, 33), Vector3(fx + 1.0, 12.9, 0), cream, false)
	Build.box(self, Vector3(0.3, 7.5, 3.4), Vector3(fx - 0.1, 3.75, 0), dark, false)
	for z in [-8.0, 8.0]:
		Build.box(self, Vector3(0.3, 5.0, 2.2), Vector3(fx - 0.1, 2.5, z), dark, false)
	# Ярус 2 с нишей и статуей святой
	Build.box(self, Vector3(3, 10, 20), Vector3(fx + 2.0, 18.5, 0), cream, false)
	for z in [-8.0, -4.0, 4.0, 8.0]:
		Build.cyl(self, 0.4, 0.36, 9.0, Vector3(fx + 0.2, 18.0, z), granite, false, 8)
	Build.box(self, Vector3(0.3, 4.0, 2.4), Vector3(fx + 0.4, 18.5, 0), Psx.color(Color("8a7a60")), false)
	Build.statue(self, Vector3(fx + 0.2, 16.4, 0), 1.5)
	Build.box(self, Vector3(3.6, 0.8, 21), Vector3(fx + 2.0, 23.8, 0), cream, false)
	# Ярус 3, фронтон, крест
	Build.box(self, Vector3(2.5, 6, 10), Vector3(fx + 2.6, 27.2, 0), cream, false)
	var ped := CSGPolygon3D.new()
	ped.polygon = PackedVector2Array([Vector2(-5.5, 0), Vector2(5.5, 0), Vector2(0, 3.2)])
	ped.depth = 2.5
	ped.material = cream
	ped.rotation.y = PI * 0.5
	ped.position = Vector3(fx + 1.35, 30.2, 0)
	add_child(ped)
	Build.box(self, Vector3(0.2, 2.0, 0.2), Vector3(fx + 2.5, 34.4, 0), Psx.color(Color("3a3a3a")), false)
	Build.box(self, Vector3(0.2, 0.2, 1.0), Vector3(fx + 2.5, 34.9, 0), Psx.color(Color("3a3a3a")), false)
	# Статуи по ярусам
	for z in [-15.0, -11.0, 11.0, 15.0]:
		Build.statue(self, Vector3(fx + 1.0, 13.5, z), 1.2)
	for z in [-9.0, 9.0]:
		Build.statue(self, Vector3(fx + 2.0, 24.2, z), 1.0)

	# Купол на барабане с фонарём
	var dome_c := Vector3(fx + 44, 22, 0)
	Build.cyl(self, 7.5, 7.5, 6.0, dome_c + Vector3(0, 3, 0), Psx.wall("cathedral", Vector2(5, 6)), false, 16)
	Build.sphere(self, 7.6, dome_c + Vector3(0, 6, 0), Psx.color(Color("e8c070")), Vector3(1, 1.25, 1), true)
	Build.cyl(self, 1.2, 1.2, 2.6, dome_c + Vector3(0, 16.5, 0), cream, false, 8)
	Build.sphere(self, 1.3, dome_c + Vector3(0, 17.8, 0), Psx.color(Color("e8c070")), Vector3.ONE, true)

	# Колокольня у северной стороны
	var tc := Vector3(fx + 18, 0, -17)
	Build.box(self, Vector3(7, 26, 7), tc + Vector3(0, 13, 0), Psx.wall("cathedral", Vector2(7, 6.5)), true)
	Build.box(self, Vector3(7.6, 0.8, 7.6), tc + Vector3(0, 26.2, 0), cream, false)
	Build.box(self, Vector3(5.5, 7, 5.5), tc + Vector3(0, 30, 0), cream, false)
	for k in [Vector3(2.8, 0, 0), Vector3(-2.8, 0, 0), Vector3(0, 0, 2.8), Vector3(0, 0, -2.8)]:
		Build.box(self, Vector3(0.2 if k.x != 0.0 else 2.0, 3.6, 2.0 if k.x != 0.0 else 0.2), tc + Vector3(0, 30, 0) + k, dark, false)
	Build.sphere(self, 3.0, tc + Vector3(0, 33.5, 0), Psx.color(Color("e8c070")), Vector3(1, 1.3, 1), true)
	Build.cyl(self, 0.8, 0.1, 2.5, tc + Vector3(0, 38.5, 0), cream, false, 6)
	# Часы на колокольне
	var clk := Build.cyl(self, 1.4, 1.4, 0.2, tc + Vector3(-3.6, 22, 0), Psx.color(Color("f4f0e0")), false, 12)
	clk.rotation.z = PI * 0.5

	# Двор перед собором за балюстрадой со статуями
	Build.ground(self, Rect2(30, -18, 11, 38), "lime", 0.3, 0.012, Color(0.85, 0.82, 0.76))
	Build.balustrade(self, Vector3(30, 0, -18), Vector3(30, 0, -2.5))
	Build.balustrade(self, Vector3(30, 0, 2.5), Vector3(30, 0, 20))
	Build.balustrade(self, Vector3(30, 0, -18), Vector3(41, 0, -18), false)
	Build.balustrade(self, Vector3(30, 0, 20), Vector3(41, 0, 20), false)

	# Сад Бадии к северу от собора: сосны-«зонтики» за балюстрадой
	Build.ground(self, Rect2(41, -21, 59, 7), "grass", 0.3, 0.012)
	Build.balustrade(self, Vector3(41, 0, -21), Vector3(66, 0, -21), false)
	Build.balustrade(self, Vector3(70, 0, -21), Vector3(100, 0, -21), false)
	for x in [45.0, 52.0, 76.0, 88.0, 96.0]:
		Build.billboard(self, Vector3(x, 0, -17.5), Vector2(10, 12.5), "pine")
	Build.billboard(self, Vector3(34, 0, -27.0 + 52.0), Vector2(9, 11), "pine")


func _elephant_fountain() -> void:
	## Фонтан со слоном: ступени, чаша, мраморный постамент,
	## слон из чёрной лавы с попоной и египетский обелиск с крестом.
	var marble := Psx.mat("lime", Color("f4efe4"), 0.6)
	var lava := Psx.mat("lava", Color("3a3a40"), 1.0)
	var c := ELEPHANT
	Build.cyl(self, 7.4, 7.4, 0.25, c + Vector3(0, 0.125, 0), marble, true, 16)
	Build.cyl(self, 7.0, 7.0, 0.25, c + Vector3(0, 0.375, 0), marble, true, 16)
	# Чаша: кольцо с коллизией (CSG), внутри вода
	var bowl := CSGCylinder3D.new()
	bowl.radius = 5.8
	bowl.height = 0.8
	bowl.sides = 16
	bowl.material = marble
	bowl.use_collision = true
	bowl.position = c + Vector3(0, 0.9, 0)
	var hole := CSGCylinder3D.new()
	hole.radius = 5.3
	hole.height = 1.0
	hole.sides = 16
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.position.y = 0.35
	bowl.add_child(hole)
	add_child(bowl)
	Build.cyl(self, 5.3, 5.3, 0.05, c + Vector3(0, 1.05, 0), Psx.color(Color("4a8ab8"), 0.3), false, 16)
	# Постамент
	Build.cyl(self, 1.9, 1.6, 1.4, c + Vector3(0, 1.2, 0), marble, true, 10)
	Build.box(self, Vector3(2.6, 2.2, 3.2), c + Vector3(0, 3.0, 0), marble, true)
	Build.box(self, Vector3(3.0, 0.35, 3.6), c + Vector3(0, 4.25, 0), marble, false)
	# Слон (смотрит на восток, к собору)
	var e := Node3D.new()
	e.position = c + Vector3(0, 4.4, 0)
	e.rotation.y = -PI * 0.5
	add_child(e)
	for p in [Vector3(-0.45, 0.55, -0.75), Vector3(0.45, 0.55, -0.75), Vector3(-0.45, 0.55, 0.75), Vector3(0.45, 0.55, 0.75)]:
		Build.cyl(e, 0.26, 0.24, 1.1, p, lava, false, 8)
	Build.box(e, Vector3(1.3, 1.25, 2.3), Vector3(0, 1.6, 0), lava, false)
	Build.sphere(e, 0.7, Vector3(0, 1.75, -1.2), lava, Vector3(1.0, 1.05, 0.9))
	for s in [-1.0, 1.0]:
		var ear := Build.box(e, Vector3(0.1, 0.9, 0.7), Vector3(0.7 * s, 1.8, -1.0), lava, false)
		ear.rotation.y = 0.4 * s
		var tusk := Build.cyl(e, 0.07, 0.03, 0.6, Vector3(0.25 * s, 1.2, -1.75), marble, false, 5)
		tusk.rotation.x = -1.1
	# Хобот: изгибается вниз и вверх
	var trunk_pts := [Vector3(0, 1.35, -1.75), Vector3(0, 0.95, -1.95), Vector3(0, 0.7, -2.15), Vector3(0, 0.8, -2.4)]
	for i in trunk_pts.size():
		Build.sphere(e, 0.2 - i * 0.03, trunk_pts[i], lava)
	# Попона и седло-постамент обелиска
	Build.box(e, Vector3(1.45, 0.25, 1.6), Vector3(0, 2.3, 0.05), marble, false)
	Build.box(e, Vector3(1.5, 0.7, 0.12), Vector3(0, 1.95, 0.05), Psx.color(Color("e8e0c8")), false)
	Build.box(e, Vector3(0.9, 0.5, 0.9), Vector3(0, 2.65, 0.05), marble, false)
	# Обелиск: четырёхгранный, сужается, пирамидка, шар и крест
	var ob := Build.cyl(e, 0.42, 0.26, 4.6, Vector3(0, 5.2, 0.05), Psx.mat("lava", Color("8a7a76"), 2.0), false, 4)
	ob.rotation.y = PI * 0.25
	var tip := Build.cyl(e, 0.26, 0.0, 0.5, Vector3(0, 7.75, 0.05), Psx.color(Color("8a7a76")), false, 4)
	tip.rotation.y = PI * 0.25
	Build.sphere(e, 0.18, Vector3(0, 8.1, 0.05), Psx.color(Color("d0b060")))
	Build.box(e, Vector3(0.06, 0.5, 0.06), Vector3(0, 8.5, 0.05), Psx.color(Color("d0b060")), false)
	Build.box(e, Vector3(0.3, 0.06, 0.06), Vector3(0, 8.6, 0.05), Psx.color(Color("d0b060")), false)


func _porta_uzeda_and_seafront() -> void:
	## Ворота Порта Узеда: арка над проездом на Виа Дузмет
	var lava := Psx.wall("facade_dark", Vector2(4, 4.5))
	var lime := Psx.mat("lime", Color("ece4d0"), 0.5)
	Build.building(self, -36, -20, 48, 54, 9, "grey")
	Build.building(self, -10, 14, 48, 54, 9, "grey")
	Build.box(self, Vector3(4, 16, 6), Vector3(16, 8, 51), lava, true)
	Build.box(self, Vector3(4, 16, 6), Vector3(28, 8, 51), lava, true)
	Build.box(self, Vector3(16, 6, 6), Vector3(22, 13, 51), lava, true)
	Build.box(self, Vector3(16.6, 0.8, 6.6), Vector3(22, 16.2, 51), lime, false)
	Build.box(self, Vector3(8.4, 0.6, 6.2), Vector3(22, 9.9, 51), lime, false)
	Build.statue(self, Vector3(22, 16.6, 48.5), 1.3)

	# Виадук с арками вдоль набережной и пальмы
	Build.box(self, Vector3(360, 9, 3), Vector3(0, 4.5, 104.5), Psx.wall("arches", Vector2(9, 9), Color.WHITE, true), true)
	Build.box(self, Vector3(360, 0.8, 3.4), Vector3(0, 9.2, 104.5), Psx.mat("lava", Color.WHITE, 0.5), false)
	for x in range(-170, 171, 16):
		Build.billboard(self, Vector3(x, 0, 101.5), Vector2(6, 9), "palm")


func _fish_market() -> void:
	## Пескерия: ряды прилавков с тентами, лёд и рыба, торговцы
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var wood := Psx.mat("wood", Color("c0a080"), 0.8)
	var ice := Psx.color(Color("dceaf0"), 0.2)
	var fish := Psx.color(Color("a8b4c0"), 0.3)
	var awning := Psx.mat("awning", Color.WHITE, 1.0, true)
	for row in 3:
		for col in 4:
			var p := Vector3(-30 + col * 11, 0, 60 + row * 9)
			Build.box(self, Vector3(4.5, 0.9, 1.8), p + Vector3(0, 0.45, 0), wood, true)
			Build.box(self, Vector3(4.3, 0.12, 1.6), p + Vector3(0, 0.96, 0), ice, false)
			for k in 7:
				var f := Build.box(self, Vector3(0.5, 0.1, 0.16), p + Vector3(rng.randf_range(-1.9, 1.9), 1.05, rng.randf_range(-0.6, 0.6)), fish, false)
				f.rotation.y = rng.randf() * TAU
			for s in [-2.1, 2.1]:
				Build.box(self, Vector3(0.08, 2.6, 0.08), p + Vector3(s, 1.3, -1.2), wood, false)
			var aw := Build.box(self, Vector3(5.0, 0.06, 3.0), p + Vector3(0, 2.6, -0.3), awning, false)
			aw.rotation.x = 0.18
			# Торговец за прилавком
			var v := Node3D.new()
			v.position = p + Vector3(rng.randf_range(-1.2, 1.2), 0, -1.6)
			add_child(v)
			NpcModels.human(v, rng, Color("e8e8f0"), Color("27305a"))
			_box_apron(v)
	# Меч-рыба на центральном прилавке
	var sw := Node3D.new()
	sw.position = Vector3(-8, 1.1, 69)
	add_child(sw)
	Build.box(sw, Vector3(0.35, 0.3, 2.0), Vector3.ZERO, Psx.color(Color("6a7a90")), false)
	Build.box(sw, Vector3(0.05, 0.05, 1.2), Vector3(0, 0.05, -1.55), Psx.color(Color("8a9aa8")), false)
	Build.box(sw, Vector3(0.05, 0.5, 0.3), Vector3(0, 0.3, 0.1), Psx.color(Color("5a6a80")), false)


func _box_apron(v: Node3D) -> void:
	Build.box(v, Vector3(0.44, 0.7, 0.05), Vector3(0, 1.0, -0.14), Psx.color(Color("f0f0f0")), false)


func _street_furniture() -> void:
	# Канделябры на площади
	for p in [Vector3(-24, 0, -18), Vector3(10, 0, -18), Vector3(-24, 0, 14), Vector3(10, 0, 14),
			Vector3(28, 0, -6), Vector3(28, 0, 8), Vector3(-24, 0, 40), Vector3(10, 0, 40)]:
		Build.lamp(self, p)
	# Фонари вдоль улиц
	for x in range(-170, -40, 20):
		Build.lamp(self, Vector3(x, 0, -35))
	for z in range(-180, -40, 20):
		Build.lamp(self, Vector3(42.5, 0, z))
	for x in range(-160, 170, 24):
		Build.lamp(self, Vector3(x, 0, 101))
	# Скамьи вокруг фонтана
	var bench := Psx.mat("lime", Color("d8d0c0"), 0.6)
	for a in [0.3, 1.9, 3.5, 5.1]:
		var p := ELEPHANT + Vector3(cos(a), 0, sin(a)) * 10.5
		Build.box(self, Vector3(2.6, 0.45, 0.7), p + Vector3(0, 0.225, 0), bench, true, -a + PI * 0.5)
	# Столики уличного кафе у западной стены
	var table := Psx.color(Color("e8e4dc"))
	var umbrella := Psx.color(Color("f0e6c8"))
	for i in 5:
		var p := Vector3(-33.5, 0, -14 + i * 7)
		Build.cyl(self, 0.45, 0.45, 0.75, p + Vector3(0, 0.375, 0), table, true, 8)
		Build.cyl(self, 0.05, 0.05, 2.4, p + Vector3(0, 1.2, 0), table, false, 4)
		Build.cyl(self, 1.6, 0.1, 0.5, p + Vector3(0, 2.5, 0), umbrella, false, 8)


# ---------- Дороги и блоки ----------

func _roads() -> void:
	## Дорожный граф. Шиканы из бетонных блоков: машины снижают скорость
	## до ~2.5 м/с и виляют между ними по центру дороги.
	var S := 2.5
	# Виа Гарибальди → площадь → Виа Витторио Эмануэле (восток)
	roads.add_polyline([Vector3(-178, 0, -28), Vector3(-60, 0, -28),
		[Vector3(-55, 0, -28), S], [Vector3(-50, 0, -25.4), S, true], [Vector3(-46, 0, -28), S, true],
		[Vector3(-42, 0, -30.6), S, true], [Vector3(-37, 0, -28), S],
		Vector3(-10, 0, -28), Vector3(22, 0, -28), Vector3(36, 0, -28),
		[Vector3(52, 0, -28), S], [Vector3(57, 0, -30.6), S, true], [Vector3(61, 0, -28), S, true],
		[Vector3(65, 0, -25.4), S, true], [Vector3(70, 0, -28), S],
		Vector3(178, 0, -28)])
	Build.barrier(self, Vector3(-50, 0, -30.4))
	Build.barrier(self, Vector3(-42, 0, -25.6))
	Build.barrier(self, Vector3(57, 0, -25.6))
	Build.barrier(self, Vector3(65, 0, -30.4))
	# Виа Этнеа на север
	roads.add_polyline([Vector3(36, 0, -28),
		[Vector3(36, 0, -45), S], [Vector3(33.4, 0, -50), S, true], [Vector3(36, 0, -54), S, true],
		[Vector3(38.6, 0, -58), S, true], [Vector3(36, 0, -63), S],
		Vector3(36, 0, -188)])
	Build.barrier(self, Vector3(38.4, 0, -50), PI * 0.5)
	Build.barrier(self, Vector3(33.6, 0, -58), PI * 0.5)
	# Через площадь мимо собора к Порта Узеда и на Дузмет
	roads.add_polyline([Vector3(22, 0, -28),
		[Vector3(22, 0, 25), S], [Vector3(24.6, 0, 30), S, true], [Vector3(22, 0, 34), S, true],
		[Vector3(19.4, 0, 38), S, true], [Vector3(22, 0, 43), S],
		Vector3(22, 0, 51), Vector3(22, 0, 95)])
	Build.barrier(self, Vector3(19.6, 0, 30), PI * 0.5)
	Build.barrier(self, Vector3(24.4, 0, 38), PI * 0.5)
	# Виа Дузмет вдоль набережной
	roads.add_polyline([Vector3(-178, 0, 95), Vector3(22, 0, 95), Vector3(178, 0, 95)])
	# Ряд блоков, не пускающих машины на площадь с юго-запада (декор)
	for x in [-30.0, -24.0, -18.0, -12.0]:
		Build.barrier(self, Vector3(x, 0, -22.5), PI * 0.5)


func _walkways() -> void:
	## Граф пешеходов: сетка по площади (в обход фонтана), кольцо вокруг
	## фонтана, тротуары вдоль улиц, двор собора, проход к рынку.
	walk.add_grid([-33.0, -21.0, -9.0, 3.0, 14.0, 28.0], [-20.0, -8.0, 4.0, 16.0, 28.0, 40.0, 46.0], ELEPHANT, 9.5)
	var ring := walk.add_ring(ELEPHANT, 9.0, 10)
	walk.connect_to_nearest(ring, 7.0)
	# Перед ратушей и переходы через проезд
	walk.add_polyline([Vector3(-34, 0, -34), Vector3(-21, 0, -34), Vector3(-9, 0, -34), Vector3(3, 0, -34), Vector3(14, 0, -34), Vector3(30, 0, -34)])
	for x in [-33.0, -9.0, 14.0]:
		walk.add_polyline([Vector3(x if x != -33.0 else -34.0, 0, -34), Vector3(x, 0, -20)])
	# Виа Гарибальди: север и юг
	walk.add_polyline([Vector3(-34, 0, -34), Vector3(-90, 0, -34), Vector3(-178, 0, -34)])
	walk.add_polyline([Vector3(-33, 0, -20), Vector3(-36, 0, -22), Vector3(-90, 0, -22), Vector3(-178, 0, -22)])
	walk.add_polyline([Vector3(-90, 0, -34), Vector3(-90, 0, -22)])
	# Виа Этнеа: обе стороны и переход
	walk.add_polyline([Vector3(30, 0, -34), Vector3(30, 0, -100), Vector3(30, 0, -188)])
	walk.add_polyline([Vector3(30, 0, -34), Vector3(42, 0, -34), Vector3(42, 0, -100), Vector3(42, 0, -188)])
	walk.add_polyline([Vector3(30, 0, -100), Vector3(42, 0, -100)])
	# Витторио Эмануэле на восток
	walk.add_polyline([Vector3(42, 0, -34), Vector3(110, 0, -34), Vector3(178, 0, -34)])
	walk.add_polyline([Vector3(28, 0, -20), Vector3(42, 0, -22.5), Vector3(102, 0, -22.5), Vector3(178, 0, -22.5)])
	# Двор собора
	walk.add_polyline([Vector3(28, 0, 4), Vector3(34, 0, 0), Vector3(39, 0, 0)])
	walk.add_polyline([Vector3(34, 0, 0), Vector3(36, 0, -12), Vector3(36, 0, 14), Vector3(34, 0, 0)])
	# Порта Узеда и Дузмет
	walk.add_polyline([Vector3(14, 0, 46), Vector3(16, 0, 56), Vector3(16, 0, 88)])
	walk.add_polyline([Vector3(28, 0, 46), Vector3(28, 0, 56), Vector3(28, 0, 88)])
	walk.add_polyline([Vector3(-178, 0, 88), Vector3(-60, 0, 88), Vector3(-15, 0, 88), Vector3(16, 0, 88), Vector3(28, 0, 88), Vector3(100, 0, 88), Vector3(178, 0, 88)])
	walk.add_polyline([Vector3(-178, 0, 101.5), Vector3(0, 0, 101.5), Vector3(178, 0, 101.5)])
	walk.add_polyline([Vector3(0, 0, 101.5), Vector3(-15, 0, 88)])
	# Рынок: проход с площади и ряды между прилавками
	walk.add_polyline([Vector3(-15, 0, 46), Vector3(-15, 0, 56)])
	walk.add_grid([-35.0, -24.5, -15.0, -2.5, 8.0], [56.0, 64.5, 73.5, 82.0])
	walk.add_polyline([Vector3(-15, 0, 82), Vector3(-15, 0, 88)])


# ---------- Фото-цели ----------

func _photo_targets() -> void:
	var spots := [
		# позиция, подпись, очки, радиус, дальность
		[ELEPHANT + Vector3(1.5, 6.3, 0), "Слон «Лиотру»", 1500, 1.4, 45.0],
		[ELEPHANT + Vector3(0, 12.6, 0), "Крест на обелиске", 900, 0.4, 45.0],
		[Vector3(41.2, 18.6, 0), "Святая Агата в нише", 1200, 1.0, 45.0],
		[Vector3(55.4, 22, -17), "Часы колокольни", 800, 1.3, 60.0],
		[Vector3(85, 34, 0), "Купол собора", 900, 6.0, 80.0],
		[Vector3(-3, 17.0, -38.2), "Часы ратуши", 700, 1.1, 50.0],
		[Vector3(-8, 1.2, 69), "Меч-рыба на рынке", 1000, 0.8, 25.0],
		[Vector3(22, 17.5, 48.5), "Статуя над Порта Узеда", 800, 1.0, 50.0],
		[Vector3(-350, 330, -1700), "Этна дымит", 1500, 160.0, 3000.0],
	]
	for s in spots:
		var t := PhotoTarget.new()
		t.position = s[0]
		t.title = s[1]
		t.points = s[2]
		t.radius = s[3]
		t.max_distance = s[4]
		add_child(t)
