class_name Walker
extends Node3D
## NPC, который ходит по графу маршрутов:
##   прохожие — по тротуарам и площади, каждый в своей «полосе» тротуара;
##   курьеры «Хвать» — по тем же тротуарам, но быстро и сами объезжают людей;
##   конная полиция — по дорогам у обочины, останавливается перед помехой.
## Если в NPC врезаться на скорости — оба падают.

enum Kind { PEDESTRIAN, COURIER, POLICE }

const KIND_NAMES := ["pedestrian", "courier", "police"]
const HIT_STRENGTH := [1.0, 1.4, 3.0]
const RADIUS := [0.35, 0.6, 1.1]

var kind: Kind = Kind.PEDESTRIAN
var graph: NavGraph
var lane := 0.0                  # смещение вправо от оси маршрута
var speed := 1.3
var variant := ""              # типаж прохожего: "", "alt_girl", "grandpa_tweed", "grandpa_cap"

var _rng := RandomNumberGenerator.new()
var _parts := {}
var _cur := 0
var _prev := -1
var _next := 0
var _wait := 0.0
var _phase := 0.0
var _knocked := 0.0
var _hit_cooldown := 0.0
var _dodge := Vector3.ZERO
var _cur_speed := 0.0


static func create(k: Kind, g: NavGraph, start_node: int, seed_value: int, lane_offset: float) -> Walker:
	var w := Walker.new()
	w.kind = k
	w.graph = g
	w.lane = lane_offset
	w._rng.seed = seed_value
	w._cur = start_node
	return w


func radius() -> float:
	return RADIUS[kind]


func _ready() -> void:
	add_to_group("npc")
	match kind:
		Kind.PEDESTRIAN:
			_parts = NpcCharacters.build(variant, self, _rng)
			match variant:
				"grandpa_cap": speed = _rng.randf_range(0.45, 0.65)      # шаркает
				"grandpa_tweed": speed = _rng.randf_range(0.8, 1.0)      # прогуливается
				"alt_girl": speed = _rng.randf_range(1.1, 1.4)
				_: speed = _rng.randf_range(0.9, 1.7)
		Kind.COURIER:
			_parts = NpcModels.courier(self, _rng)
			speed = _rng.randf_range(4.5, 6.0)
		Kind.POLICE:
			_parts = NpcModels.police_horse(self, _rng)
			speed = 1.8
	_phase = _rng.randf() * TAU
	_next = graph.next_from(_cur, -1, _rng)
	# Стартуем где-то посередине ребра
	var a := _lane_point(_cur)
	var b := _lane_point(_next)
	global_position = a.lerp(b, _rng.randf())
	var d := b - a
	if d.length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)
	_cur_speed = speed

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitorable = false
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	match kind:
		Kind.PEDESTRIAN: sh.size = Vector3(0.6, 1.8, 0.5)
		Kind.COURIER: sh.size = Vector3(0.7, 1.8, 1.6)
		Kind.POLICE: sh.size = Vector3(0.9, 2.6, 2.2)
	col.shape = sh
	col.position.y = sh.size.y * 0.5
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(_on_body)


func _on_body(body: Node3D) -> void:
	if not body is Scooter or _hit_cooldown > 0.0:
		return
	var p := body as Scooter
	_hit_cooldown = 1.5
	var fast := absf(p.speed) > 3.5 or p.airborne
	p.on_npc_hit(KIND_NAMES[kind], HIT_STRENGTH[kind])
	if kind == Kind.POLICE:
		Game.trick_popup.emit("ШТРАФ −500")
		Game.add_score(-500)
	elif fast:
		knock()


func knock() -> void:
	if _knocked > 0.0:
		return
	_knocked = 2.5
	var body: Node3D = _parts.body
	var tw := create_tween()
	tw.tween_property(body, "rotation:x", 1.45, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(1.6)
	tw.tween_property(body, "rotation:x", 0.0, 0.5)


func _lane_point(i: int) -> Vector3:
	var a := graph.points[_cur]
	var b := graph.points[_next]
	var dir := b - a
	dir.y = 0.0
	if dir.length() < 0.01:
		return graph.points[i]
	return graph.points[i] + dir.normalized().cross(Vector3.UP) * lane


func _process(delta: float) -> void:
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if _knocked > 0.0:
		_knocked -= delta
		return
	_dodge = _dodge.move_toward(Vector3.ZERO, delta * 3.0)
	if kind != Kind.POLICE:
		_dodge_cars()

	if _wait > 0.0:
		_wait -= delta
		_animate(delta, 0.0)
		return

	var target := _lane_point(_next)
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.7:
		_advance()
		return
	var fwd := to.normalized()
	var want := speed
	var steer := Vector3.ZERO
	match kind:
		Kind.COURIER:
			var r := _avoid_people(fwd, 4.5, 1.4)
			steer = r.steer
			want = r.speed
		Kind.POLICE:
			want = _avoid_people(fwd, 5.0, 1.8).speed
		Kind.PEDESTRIAN:
			_dodge_player()

	_cur_speed = move_toward(_cur_speed, want, 6.0 * delta)
	var step := (fwd + steer).normalized() * _cur_speed + _dodge
	global_position += step * delta
	if step.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-step.x, -step.z), clampf(6.0 * delta, 0.0, 1.0))
	_animate(delta, step.length())


func _advance() -> void:
	_prev = _cur
	_cur = _next
	_next = graph.next_from(_cur, _prev, _rng)
	if kind == Kind.PEDESTRIAN and _rng.randf() < 0.12:
		_wait = _rng.randf_range(1.0, 4.0)


func _avoid_people(fwd: Vector3, look: float, half_width: float) -> Dictionary:
	## Смотрит вперёд: кто в коридоре — объезжаем (курьер) или тормозим (полиция)
	var right := fwd.cross(Vector3.UP)
	var steer := Vector3.ZERO
	var spd := speed
	for n in get_tree().get_nodes_in_group("npc") + get_tree().get_nodes_in_group("player"):
		if n == self:
			continue
		var other := n as Node3D
		var d := other.global_position - global_position
		d.y = 0.0
		var ahead := d.dot(fwd)
		if ahead <= 0.0 or ahead > look:
			continue
		var side := d.dot(right)
		var r := half_width + ((other as Walker).radius() if other is Walker else 0.5)
		if absf(side) > r:
			continue
		var urgency := 1.0 - ahead / look
		if kind == Kind.COURIER:
			# Уходим в сторону, противоположную человеку
			var s := -1.0 if side > 0.0 else 1.0
			steer += right * s * (0.6 + urgency * 1.6)
			if ahead < 1.6:
				spd = minf(spd, 1.5)
			else:
				spd = minf(spd, speed * (0.55 + 0.45 * (1.0 - urgency)))
		else:
			spd = 0.0 if ahead < look * 0.6 else minf(spd, speed * 0.4)
	return {"steer": steer, "speed": spd}


func _dodge_cars() -> void:
	for c in get_tree().get_nodes_in_group("car"):
		var car := c as Node3D
		var d := global_position - car.global_position
		d.y = 0.0
		if d.length() < 6.0:
			var side := car.global_basis.x
			var s := signf(d.dot(side))
			if s == 0.0:
				s = 1.0
			_dodge = side * s * 3.0
			_wait = 0.0


func _dodge_player() -> void:
	for pl in get_tree().get_nodes_in_group("player"):
		var p := pl as Scooter
		var d2 := global_position - p.global_position
		d2.y = 0.0
		if d2.length() < 3.0 and absf(p.speed) > 6.0 and _rng.randf() < 0.05:
			_dodge = d2.normalized().cross(Vector3.UP) * 3.0 * (1.0 if _rng.randf() < 0.5 else -1.0)


func _animate(delta: float, moving_speed: float) -> void:
	var legs: Array = _parts.get("legs", [])
	var arms: Array = _parts.get("arms", [])
	if moving_speed > 0.05:
		_phase += delta * (moving_speed * 4.0 if kind != Kind.COURIER else 8.0)
	var swing := sin(_phase) * (0.5 if moving_speed > 0.05 else 0.0)
	match kind:
		Kind.PEDESTRIAN:
			var stride := 0.45 if variant == "grandpa_cap" else 1.0
			legs[0].rotation.x = swing * stride
			legs[1].rotation.x = -swing * stride
			arms[0].rotation.x = -swing * 0.8
			arms[1].rotation.x = swing * 0.8
			(_parts.body as Node3D).position.y = absf(sin(_phase)) * 0.04 * stride if moving_speed > 0.05 else 0.0
		Kind.COURIER:
			var pedal := sin(_phase) * 0.5 if moving_speed > 0.3 else 0.0
			legs[0].rotation.x = -0.9 + pedal
			legs[1].rotation.x = -0.9 - pedal
		Kind.POLICE:
			for i in legs.size():
				legs[i].rotation.x = sin(_phase + (PI if i % 3 == 0 else 0.0)) * (0.35 if moving_speed > 0.1 else 0.0)
			(_parts.neck as Node3D).rotation.x = -0.6 + sin(_phase * 2.0) * 0.05
