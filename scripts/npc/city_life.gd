class_name CityLife
extends Node3D
## Жизнь города поверх графов, которые даёт уровень:
##   walk_graph — тротуары и площадь (прохожие, курьеры)
##   road_graph — дороги (машины, конная полиция)
## Плюс прокатные самокаты: разряженные «сервис» переставляет подальше.

@export var pedestrians := 90
@export var couriers := 10
@export var police := 2
@export var car_interval := Vector2(25.0, 55.0)
@export var max_cars := 3
@export var scooter_count := 5
@export var service_delay := 25.0

var walk_graph: NavGraph
var road_graph: NavGraph
var scooter_spots: Array[Vector3] = []

var _rng := RandomNumberGenerator.new()
var _car_timer := 0.0


func _ready() -> void:
	_rng.seed = 42
	var n := walk_graph.points.size()
	for i in pedestrians:
		var lane := _rng.randf_range(0.3, 1.6) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var w := Walker.create(Walker.Kind.PEDESTRIAN, walk_graph, _rng.randi() % n, _rng.randi(), lane)
		w.variant = _pick_variant()
		add_child(w)
	for i in couriers:
		add_child(Walker.create(Walker.Kind.COURIER, walk_graph, _rng.randi() % n, _rng.randi(), 0.6))
	if road_graph:
		var rn := road_graph.points.size()
		for i in police:
			add_child(Walker.create(Walker.Kind.POLICE, road_graph, (i * 7 + 3) % rn, _rng.randi(), 3.0))

	var spots := scooter_spots.duplicate()
	spots.shuffle()
	for i in mini(scooter_count, spots.size()):
		add_child(ScooterPickup.create(spots[i], _rng.randf() * TAU, _rng.randf_range(0.45, 1.0)))

	_car_timer = _rng.randf_range(5.0, 10.0)


func _pick_variant() -> String:
	## Доли типажей в толпе
	var r := _rng.randf()
	if r < 0.25:
		return "alt_girl"
	if r < 0.36:
		return "grandpa_tweed"
	if r < 0.47:
		return "grandpa_cap"
	return ""


func _process(delta: float) -> void:
	if road_graph:
		_car_timer -= delta
		if _car_timer <= 0.0:
			_car_timer = _rng.randf_range(car_interval.x, car_interval.y)
			if get_tree().get_nodes_in_group("car").size() < max_cars:
				spawn_car()

	for p in get_tree().get_nodes_in_group("scooter_pickup"):
		var sp := p as ScooterPickup
		if sp.dead_time > service_delay and not scooter_spots.is_empty():
			sp.relocate(_free_spot(), _rng.randf() * TAU, _rng.randf_range(0.6, 1.0))


func spawn_car() -> Car:
	var c := Car.create(road_graph, _rng)
	add_child(c)
	return c


func _free_spot() -> Vector3:
	var players := get_tree().get_nodes_in_group("player")
	var best := scooter_spots[0]
	var best_d := -1.0
	for s in scooter_spots:
		var d := 1e9
		for p in players:
			d = minf(d, (p as Node3D).global_position.distance_to(s))
		for q in get_tree().get_nodes_in_group("scooter_pickup"):
			d = minf(d, (q as Node3D).global_position.distance_to(s) * 2.0)
		d += _rng.randf() * 10.0
		if d > best_d:
			best_d = d
			best = s
	return best
