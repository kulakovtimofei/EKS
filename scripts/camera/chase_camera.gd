class_name ChaseCamera
extends Camera3D
## Камера как в аркадах конца 90-х: низко и близко за спиной, смотрит
## по направлению движения (а не туда, куда повёрнут райдер в трюке),
## в воздухе чуть отъезжает, на скорости расширяет FOV.

@export var target_path: NodePath
@export var distance := 3.6
@export var height := 1.35
@export var look_height := 1.15
@export var look_ahead := 1.5
@export var air_pull_back := 1.2
@export var follow_speed := 7.0
@export var yaw_speed := 4.0
@export var base_fov := 70.0
@export var speed_fov := 12.0

var zoom_fov := 0.0         # >0 — фото-режим
var _target: Scooter
var _shake := 0.0
var _yaw := 0.0
var _air_k := 0.0


func _ready() -> void:
	_target = get_node(target_path) as Scooter
	_yaw = _target.heading_yaw()
	fov = base_fov
	near = 0.08


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if _target == null:
		return
	_yaw = lerp_angle(_yaw, _target.heading_yaw(), clampf(yaw_speed * delta, 0.0, 1.0))
	_air_k = lerpf(_air_k, 1.0 if _target.airborne else 0.0, clampf(3.0 * delta, 0.0, 1.0))

	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var tp := _target.global_position
	var want := tp + back * (distance + air_pull_back * _air_k) + Vector3.UP * (height + 0.6 * _air_k)
	# Камера не должна проваливаться под землю
	want.y = maxf(want.y, tp.y + 0.6)
	global_position = global_position.lerp(want, clampf(follow_speed * delta, 0.0, 1.0))
	look_at(tp + Vector3.UP * look_height - back * look_ahead)

	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		h_offset = randf_range(-1, 1) * _shake * 0.25
		v_offset = randf_range(-1, 1) * _shake * 0.25
	else:
		h_offset = 0.0
		v_offset = 0.0

	var want_fov := base_fov + speed_fov * clampf(absf(_target.speed) / _target.max_speed, 0.0, 1.0)
	if zoom_fov > 0.0:
		want_fov = zoom_fov
	fov = lerpf(fov, want_fov, clampf(8.0 * delta, 0.0, 1.0))
