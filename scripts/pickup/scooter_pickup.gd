class_name ScooterPickup
extends Node3D
## Припаркованный прокатный электросамокат. Подъезжаешь медленно,
## жмёшь E — пересаживаешься: забираешь его заряд, а свой старый самокат
## оставляешь на месте. Разряженные самокаты со временем «увозит сервис»,
## и они появляются заряженными в другом месте.

signal taken(pickup: ScooterPickup)

const COLORS := [Color("39d0ff"), Color("ffe600"), Color("7dff4a"), Color("ff7a00"), Color("c86bff")]

var charge := 1.0
var dead_time := 0.0              # сколько секунд стоит разряженным
var _label: Label3D
var _player_near: Scooter
var _model: Node3D


static func create(pos: Vector3, yaw: float, charge_value: float) -> ScooterPickup:
	var p := ScooterPickup.new()
	p.position = pos
	p.rotation.y = yaw
	p.charge = charge_value
	return p


func _ready() -> void:
	add_to_group("scooter_pickup")
	_model = Node3D.new()
	_model.rotation.z = 0.12           # стоит на подножке, чуть завален
	add_child(_model)
	RiderModel.build_scooter(_model, COLORS[randi() % COLORS.size()])

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 1.7
	_label.font_size = 64
	_label.pixel_size = 0.006
	_label.outline_size = 12
	_label.no_depth_test = false
	add_child(_label)
	_update_label()

	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 2.2
	col.shape = sh
	col.position.y = 0.5
	area.add_child(col)
	area.monitoring = true
	area.monitorable = false
	add_child(area)
	area.body_entered.connect(_on_enter)
	area.body_exited.connect(_on_exit)

	var tw := create_tween().set_loops()
	tw.tween_property(_label, "position:y", 1.85, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_label, "position:y", 1.7, 0.8).set_trans(Tween.TRANS_SINE)


func _update_label() -> void:
	var pct := int(round(charge * 100.0))
	_label.text = "%d%%" % pct
	if charge > 0.6:
		_label.modulate = Color("39ff14")
	elif charge > 0.25:
		_label.modulate = Color("ffe600")
	else:
		_label.modulate = Color("ff3030")


func _on_enter(body: Node3D) -> void:
	if body is Scooter:
		_player_near = body
		Game.prompt_changed.emit("E — пересесть на самокат (%d%%)" % int(round(charge * 100.0)))


func _on_exit(body: Node3D) -> void:
	if body == _player_near:
		_player_near = null
		Game.prompt_changed.emit("")


func _process(delta: float) -> void:
	if charge < 0.2:
		dead_time += delta
	if _player_near and Input.is_action_just_pressed("interact"):
		_swap(_player_near)


func _swap(player: Scooter) -> void:
	if absf(player.speed) > 4.0 or player.airborne or player.bailed:
		Game.trick_popup.emit("Притормози!")
		return
	# Меняемся местами и зарядом
	var old_charge := player.battery
	var player_xf := player.global_transform
	player.global_position = global_position + Vector3.UP * 0.05
	player.rotation.y = global_rotation.y
	player.speed = 0.0
	player.velocity = Vector3.ZERO
	player.set_battery(charge)
	global_position = player_xf.origin
	rotation.y = player_xf.basis.get_euler().y
	charge = old_charge
	dead_time = 0.0
	_update_label()
	Game.trick_popup.emit("Новый самокат!")
	Game.prompt_changed.emit("")
	_player_near = null
	taken.emit(self)


func relocate(pos: Vector3, yaw: float, new_charge: float) -> void:
	global_position = pos
	rotation.y = yaw
	charge = new_charge
	dead_time = 0.0
	_update_label()
