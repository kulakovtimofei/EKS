class_name PhotoMode
extends Node
## Фото-мини-игра. Держи «photo» (F / ПКМ) — видоискатель и замедление,
## отпусти — снимок. Очки за лучшую цель в кадре: центровка × крупность
## × бонус, если снимаешь прямо во время трюка.

signal viewfinder_changed(active: bool)
signal photo_scored(result: Dictionary)

@export var camera_path: NodePath
@export var player_path: NodePath
@export var zoom_fov := 42.0
@export var aim_time_scale := 0.5
@export var max_distance := 45.0

var active := false
var _camera: ChaseCamera
var _player: Scooter
var _hud: CanvasLayer


func _ready() -> void:
	_camera = get_node(camera_path) as ChaseCamera
	_player = get_node(player_path) as Scooter
	DirAccess.make_dir_recursive_absolute("user://photos")


func set_hud(hud: CanvasLayer) -> void:
	_hud = hud


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("photo") and not _player.bailed:
		_set_active(true)
	elif active and Input.is_action_just_released("photo"):
		_shoot()
		_set_active(false)


func _set_active(on: bool) -> void:
	active = on
	_camera.zoom_fov = zoom_fov if on else 0.0
	Game.request_time_scale("photo", aim_time_scale if on else 1.0)
	viewfinder_changed.emit(on)


func _shoot() -> void:
	var result := _evaluate()
	if result.points > 0:
		Game.add_score(result.points)
		if result.target:
			(result.target as PhotoTarget).captured = true
	result["path"] = await _save_image()
	photo_scored.emit(result)


func _evaluate() -> Dictionary:
	var best := {"points": 0, "title": "Мимо кадра", "target": null, "grade": "—"}
	var vp_size := _camera.get_viewport().get_visible_rect().size
	var center := vp_size * 0.5
	var space := _camera.get_world_3d().direct_space_state

	for node in get_tree().get_nodes_in_group("photo_target"):
		var t := node as PhotoTarget
		if t == null or (t.once and t.captured):
			continue
		var pos := t.global_position
		if not _camera.is_position_in_frustum(pos):
			continue
		var dist := _camera.global_position.distance_to(pos)
		if dist > (t.max_distance if t.max_distance > 0.0 else max_distance):
			continue
		# Не загорожено ли?
		var q := PhysicsRayQueryParameters3D.create(_camera.global_position, pos)
		q.exclude = [_player.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and hit.position.distance_to(pos) > t.radius:
			continue

		var sp := _camera.unproject_position(pos)
		var off := (sp - center).length() / center.length()
		var centering := clampf(1.0 - off * 1.4, 0.0, 1.0)
		# Видимый размер: радиус в пикселях относительно высоты кадра
		var px := t.radius / (dist * tan(deg_to_rad(_camera.fov) * 0.5))
		var size_score := clampf(px * 2.0, 0.15, 1.0)
		var style := 2.0 if _player.is_doing_trick() else (1.3 if _player.airborne else 1.0)
		var pts := int(t.points * centering * size_score * style)
		if pts > best.points:
			var grade := "C"
			var q01 := centering * size_score
			if q01 > 0.75: grade = "S"
			elif q01 > 0.5: grade = "A"
			elif q01 > 0.3: grade = "B"
			best = {"points": pts, "title": t.title, "target": t, "grade": grade, "style": style > 1.0}
	return best


func _save_image() -> String:
	# Прячем интерфейс, ждём кадр, снимаем
	if _hud:
		_hud.visible = false
	await RenderingServer.frame_post_draw
	var img := _camera.get_viewport().get_texture().get_image()
	if _hud:
		_hud.visible = true
	var path := "user://photos/eks_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	img.save_png(path)
	return path
