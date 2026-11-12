extends Node
## Автотест жизни города на карте Катании:
## godot --headless --path . res://tests/city_test.tscn

var failures := 0


func _check(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		failures += 1


func _ready() -> void:
	Engine.max_fps = 30
	Engine.time_scale = 3.0   # ускоряем симуляцию
	var level: Node3D = (load("res://scenes/levels/catania_duomo.tscn") as PackedScene).instantiate()
	add_child(level)
	_run.call_deferred(level)


func _run(level: Node3D) -> void:
	var life := level.find_child("CityLife", true, false) as CityLife
	var walk: NavGraph = level.walk
	var barriers: Array[Vector3] = [Vector3(-50, 0, -30.4), Vector3(-42, 0, -25.6), Vector3(57, 0, -25.6), Vector3(65, 0, -30.4),
		Vector3(38.4, 0, -50), Vector3(33.6, 0, -58), Vector3(19.6, 0, 30), Vector3(24.4, 0, 38)]
	await get_tree().process_frame
	var player := level.find_child("Player", true, false) as Scooter
	player.global_position = Vector3(-150, 0.3, 60)   # убираем райдера с дороги
	_check(walk.points.size() > 80, "граф тротуаров: %d узлов" % walk.points.size())
	_check(level.roads.terminals().size() >= 5, "граф дорог: %d выездов" % level.roads.terminals().size())

	for i in 4:
		life.spawn_car()
	var max_chicane_speed := 0.0
	var barrier_hits := 0
	var courier_close := 0
	var off_path := 0
	var cars_seen := 0
	var frames := 0
	var dt := 1.0 / 30.0
	while frames < 1800:
		frames += 1
		await get_tree().process_frame
		var cars := get_tree().get_nodes_in_group("car")
		cars_seen = maxi(cars_seen, cars.size())
		for c in cars:
			var car := c as Car
			for b in barriers:
				var d := Vector2(car.global_position.x - b.x, car.global_position.z - b.z).length()
				if d < 4.0:
					max_chicane_speed = maxf(max_chicane_speed, car._speed)
				if d < 0.9:
					barrier_hits += 1
		if frames % 10 == 0:
			for n in get_tree().get_nodes_in_group("npc"):
				var w := n as Walker
				if w.kind == Walker.Kind.COURIER and w._cur_speed > 2.0:
					for m in get_tree().get_nodes_in_group("npc"):
						var o := m as Walker
						if o.kind == Walker.Kind.PEDESTRIAN and o._knocked <= 0.0 and o.global_position.distance_to(w.global_position) < 0.45:
							courier_close += 1
				if w.kind == Walker.Kind.PEDESTRIAN:
					var best := INF
					for i in walk.points.size():
						for j in walk.links[i]:
							best = minf(best, NavGraph._seg_dist(w.global_position, walk.points[i], walk.points[j]))
					if best > 4.5:
						off_path += 1
		if frames == 900:
			for i in 3:
				life.spawn_car()
	for c in get_tree().get_nodes_in_group("car"):
		var car := c as Car
		print("     машина: точка %d/%d, скорость %.1f, позиция %s" % [car._i, car.path.size(), car._speed, car.global_position.round()])
	_check(cars_seen > 0, "машины появляются (макс. одновременно %d)" % cars_seen)
	_check(max_chicane_speed > 0.0 and max_chicane_speed <= 3.3, "в шикане машины ползут: макс %.1f м/с" % max_chicane_speed)
	_check(barrier_hits == 0, "машины не проезжают сквозь блоки (%d)" % barrier_hits)
	_check(courier_close <= 3, "курьеры объезжают людей (впритирку: %d)" % courier_close)
	_check(off_path == 0, "прохожие ходят по тротуарам (сошли: %d)" % off_path)
	print("ИТОГ: %s" % ("всё прошло" if failures == 0 else "%d провалов" % failures))
	get_tree().quit(failures)
