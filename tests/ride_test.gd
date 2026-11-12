extends Node
## Автотест езды без окна:
## godot --headless --path . res://tests/ride_test.tscn

var player: Scooter
var failures := 0


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/levels/test_park.tscn")
	add_child(scene.instantiate())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		failures += 1


func _run() -> void:
	await _frames(10)
	player = find_child("Player", true, false) as Scooter
	# Толпу убираем, чтобы проверки были детерминированными
	find_child("CityLife", true, false).free()
	await _frames(30)
	_check(player.is_on_floor(), "стоит на земле, y=%.2f" % player.global_position.y)

	Input.action_press("push")
	await _frames(120)
	_check(player.speed > 8.0, "разгон: %.1f м/с" % player.speed)
	var z0 := player.global_position.z
	await _frames(30)
	_check(player.global_position.z < z0 - 2.0, "едет вперёд (-Z)")
	Input.action_release("push")

	# Олли
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(10)
	_check(player.airborne, "олли: в воздухе, y=%.2f" % player.global_position.y)
	await _frames(60)
	_check(not player.airborne and not player.bailed, "чистое приземление после олли")

	# Олли + 360
	Input.action_press("push")
	await _frames(40)
	Input.action_release("push")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	Input.action_press("turn_left")
	var spun := 0
	for i in 70:
		await get_tree().physics_frame
		if absf(player._air_yaw) >= TAU - 0.3:
			break
		spun = i
	Input.action_release("turn_left")
	print("     вращение: %.0f°" % rad_to_deg(player._air_yaw))
	await _frames(80)
	_check(not player.bailed or absf(player._air_yaw) < 0.01, "приземление после вращения обработано")

	# Трюк + замедление
	Engine.time_scale = 1.0
	Input.action_press("push")
	await _frames(40)
	Input.action_release("push")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(3)
	Input.action_press("slowmo")
	Input.action_press("trick")
	await _frames(2)
	Input.action_release("trick")
	await _frames(5)
	_check(Engine.time_scale < 0.5, "замедление включено: %.2f" % Engine.time_scale)
	Input.action_release("slowmo")
	await _frames(200)
	_check(Engine.time_scale == 1.0, "время вернулось к норме")
	_check(Game.total_score > 0, "очки за трюк начислены: %d" % Game.total_score)

	# Каждый трюк с обычного олли приземляется чисто
	for dir in ["", "push", "brake", "turn_left"]:
		player.respawn()
		await _frames(10)
		player.speed = 8.0
		Input.action_press("jump")
		await _frames(2)
		Input.action_release("jump")
		await _frames(4)
		if dir != "":
			Input.action_press(dir)
		Input.action_press("trick")
		await _frames(2)
		Input.action_release("trick")
		if dir != "":
			Input.action_release(dir)
		var bailed := false
		for i in 60:
			await get_tree().physics_frame
			bailed = bailed or player.bailed
		_check(not bailed, "трюк «%s» с обычного олли — чистая посадка" % (dir if dir != "" else "без направления"))

	# Разворот 180: руль зажат уже в воздухе
	player.respawn()
	await _frames(10)
	player.speed = 8.0
	Input.action_press("jump")
	await _frames(12)                    # держим — олли повыше
	Input.action_release("jump")
	await _frames(3)
	Input.action_press("turn_left")
	await _frames(13)
	Input.action_release("turn_left")
	var bailed2 := false
	for i in 60:
		await get_tree().physics_frame
		bailed2 = bailed2 or player.bailed
	_check(not bailed2, "разворот в воздухе — чистая посадка (автодоворот)")

	# Олли, упёршись в край плиты — прыжок должен уйти вверх
	player.respawn()
	await _frames(10)
	player.global_position = Vector3(0, 0.05, -12.9)   # вплотную к мануал-паду (z -14.5..-17.5) сзади
	player.rotation.y = 0.0
	player.speed = 0.0
	await _frames(10)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var peak := 0.0
	for i in 30:
		await get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)
	_check(peak > 0.8, "олли у края бордюра уходит вверх: пик %.2f м" % peak)

	# Батарея: на нуле мотор не тянет, только толчки ногой
	player.respawn()
	await _frames(20)
	player.set_battery(0.0)
	Input.action_press("push")
	await _frames(240)
	_check(player.speed <= player.kick_max_speed + 0.1 and player.speed > 2.0, "пустая батарея: толкаемся, %.1f м/с" % player.speed)
	player.respawn()
	await _frames(10)
	player.set_battery(1.0)
	await _frames(90)
	_check(player.speed > 10.0, "полная батарея: мотор тянет, %.1f м/с" % player.speed)
	_check(player.battery < 1.0, "заряд расходуется: %.3f" % player.battery)

	# Пересадка на прокатный самокат
	player.speed = 0.0
	Input.action_release("push")
	await _frames(30)
	var pick := ScooterPickup.create(player.global_position + Vector3(0, 0, -1.0), 0.0, 0.8)
	add_child(pick)
	player.set_battery(0.1)
	await _frames(10)
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(5)
	_check(absf(player.battery - 0.8) < 0.01 and absf(pick.charge - 0.1) < 0.01, "пересадка: заряд %.2f, оставленный %.2f" % [player.battery, pick.charge])
	pick.queue_free()

	# Столкновение с пешеходом на скорости
	player.respawn()
	await _frames(20)
	var g := NavGraph.new()
	var pp := player.global_position
	g.add_polyline([pp + Vector3(0, 0, -14), pp + Vector3(0, 0, -14.3)])
	var ped := Walker.create(Walker.Kind.PEDESTRIAN, g, 0, 1, 0.0)
	add_child(ped)
	ped.speed = 0.0
	Input.action_press("push")
	await _frames(150)
	Input.action_release("push")
	_check(player.bailed or player.speed < 3.0, "врезался в прохожего — падение")

	# Машина проезжает
	var rg := NavGraph.new()
	rg.add_polyline([Vector3(40, 0, 60), Vector3(40, 0, -60)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var car := Car.create(rg, rng)
	car.path = rg.route_points(PackedInt32Array([0, 1]), 0.0)
	add_child(car)
	await _frames(120)
	_check(is_instance_valid(car) and car.global_position.z < 50.0, "машина едет: z=%.1f" % car.global_position.z)

	print("ИТОГ: %s" % ("всё прошло" if failures == 0 else "%d провалов" % failures))
	get_tree().quit(failures)
