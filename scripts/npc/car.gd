class_name Car
extends Node3D
## Машина едет по графу дорог от одного края карты до другого.
## В шиканах из бетонных блоков сбрасывает скорость и аккуратно виляет.
## Тормозит перед людьми, лошадьми, машинами и райдером; если стоит
## долго — сигналит и протискивается ползком. Врезался — падение.

var cruise := 8.5
var path: Array[Dictionary] = []

var _i := 1
var _speed := 0.0
var _blocked := 0.0
var _honked := false
var _rng := RandomNumberGenerator.new()


static func create(roads: NavGraph, rng: RandomNumberGenerator) -> Car:
	var c := Car.new()
	c._rng.seed = rng.randi()
	var ends := roads.terminals()
	var start := ends[rng.randi() % ends.size()]
	var route := roads.random_route(start, rng)
	c.path = roads.route_points(route, 1.7)
	return c


func _ready() -> void:
	add_to_group("car")
	if path.size() < 2:
		queue_free()
		return
	global_position = path[0].pos
	var d: Vector3 = path[1].pos - path[0].pos
	rotation.y = atan2(-d.x, -d.z)
	NpcModels.car(self, _rng)
	_speed = cruise * 0.6

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitorable = false
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.9, 1.5, 4.3)
	col.shape = sh
	col.position.y = 0.75
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(func(b: Node3D) -> void:
		if b is Scooter:
			(b as Scooter).on_npc_hit("car", 5.0)
			Game.trick_popup.emit("БИИИП!"))


func radius() -> float:
	return 1.2


func current_limit() -> float:
	## Ограничение действует на подъезде к медленной точке и сразу после неё
	var limit := cruise
	var prev: Dictionary = path[maxi(_i - 1, 0)]
	var nxt: Dictionary = path[_i]
	if prev.slow > 0.0 and global_position.distance_to(prev.pos) < 5.0:
		limit = minf(limit, prev.slow)
	if nxt.slow > 0.0:
		# Плавное торможение: на 14 м до точки — уже почти лимит
		var d := global_position.distance_to(nxt.pos)
		limit = minf(limit, lerpf(nxt.slow, cruise, clampf((d - 3.0) / 14.0, 0.0, 1.0)))
	return limit


func _process(delta: float) -> void:
	if path.is_empty():
		return
	var target: Vector3 = path[_i].pos
	var to := target - global_position
	to.y = 0.0
	if to.length() < 1.4:
		_i += 1
		if _i >= path.size():
			queue_free()
		return

	# Поворот к цели; на малой скорости руль «доворачивает» быстрее
	var want_yaw := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, want_yaw, clampf(2.8 * delta * (1.0 + 4.0 / maxf(_speed, 1.0)), 0.0, 1.0))

	var limit := current_limit()
	if _obstacle_ahead():
		_blocked += delta
		limit = 0.0 if _blocked < 4.0 else 1.0
		if _blocked > 1.2 and not _honked:
			_honked = true
			Game.trick_popup.emit("БИП-БИП!")
	else:
		_blocked = 0.0
		_honked = false
	var rate := 4.0 if _speed < limit else 10.0
	_speed = move_toward(_speed, limit, rate * delta)
	global_position += -global_basis.z * _speed * delta


func _obstacle_ahead() -> bool:
	var fwd := -global_basis.z
	var right := global_basis.x
	var look := 4.0 + _speed * 0.8
	for g in ["npc", "car", "player"]:
		for n in get_tree().get_nodes_in_group(g):
			if n == self:
				continue
			var d := (n as Node3D).global_position - global_position
			var ahead := d.dot(fwd)
			if ahead > 2.0 and ahead < 2.0 + look and absf(d.dot(right)) < 1.5:
				return true
	return false
