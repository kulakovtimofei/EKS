class_name Scooter
extends CharacterBody3D
## Самокат и райдер.
## Физика: тело — шар, который катится по любой поверхности. На земле
## up_direction следует за нормалью, поэтому можно заезжать на квотеры
## и вёрт. Скорость — скаляр вдоль поверхности, гравитация тянет вниз по
## склону. На вылете с вёрта горизонтальный снос гасится, чтобы райдер
## вернулся на тот же склон. При приземлении курс берётся из вектора
## скорости, а разворот тела сверяется с ним: вперёд или задом (фейки)
## чисто, боком — падение.

@export var max_speed := 17.0
@export var push_accel := 9.0
@export var brake_force := 16.0
@export var rolling_friction := 0.5
@export var turn_speed := 2.7
@export var jump_velocity := 8.0
@export var gravity := 22.0
@export var air_spin_speed := 7.5
@export var land_grace := 0.45

@export_group("Электромотор")
@export var battery_drain := 1.0 / 75.0   # доля заряда в секунду на полном газу
@export var idle_drain := 1.0 / 900.0     # фоновая (фара, контроллер)
@export var kick_accel := 3.0             # толкаемся ногой, когда сел аккумулятор
@export var kick_max_speed := 6.0

const RADIUS := 0.4
const GROUND_MAX := 0.87      # ~50°: перегиб между соседними гранями, при котором ещё «едем»
const LAND_MAX := 1.52        # ~87°: на что можно приземлиться из воздуха
const LAND_TOLERANCE := 1.2   # рад (~70°): боком — только почти ровно поперёк
const TRICK_DONE := 0.65      # трюк засчитан и докручивается сам, если выполнен на 65%
const AUTO_ALIGN := 5.0       # рад/с: без нажатий в воздухе доворачиваемся к ровной посадке
const MAX_CHARGE := 0.35      # с: удерживай прыжок — олли выше

const TRICKS := {
	"forward": {"name": "Комета вперёд", "points": 400, "dur": 0.5},
	"back":    {"name": "Обратная петля", "points": 450, "dur": 0.55},
	"side":    {"name": "Пропеллер руля", "points": 250, "dur": 0.32},
	"none":    {"name": "Хвостовой вихрь", "points": 300, "dur": 0.38},
}

signal battery_empty

var speed := 0.0               # >0 вперёд, <0 задом (фейки)
var battery := 1.0             # 0..1
var _low_warned := false
var airborne := false
var bailed := false

var _align: Node3D             # наклон по нормали земли
var _pose: Node3D              # вращения трюков
var _deck: Node3D
var _bars: Node3D
var _rider: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []

var _ground_n := Vector3.UP
var _was_on_floor := true
var _air_yaw := 0.0
var _heading_yaw := 0.0
var _trick_kind := ""
var _trick_t := 0.0
var _trick_dur := 0.0
var _grace := 0.0
var _manual := false
var _balance := 0.0
var _balance_vel := 0.0
var _bail_timer := 0.0
var _push_anim := 0.0
var _spawn: Transform3D
var _charging := false
var _jump_down := false
var _jump_edge := false     # своё определение нажатия — надёжнее just_pressed в физике
var _charge := 0.0
var _spin_input := false


func _ready() -> void:
	add_to_group("player")
	_spawn = global_transform
	_heading_yaw = global_rotation.y
	floor_snap_length = 0.5
	floor_max_angle = LAND_MAX
	floor_stop_on_slope = false
	floor_block_on_wall = false
	floor_constant_speed = false
	safe_margin = 0.02
	_build_body()


# ---------- Публичное ----------

func is_doing_trick() -> bool:
	return _trick_t > 0.0 or (airborne and absf(_air_yaw) > 1.0)


func heading_yaw() -> float:
	## Куда реально едем — для камеры
	return _heading_yaw


func landing_ok() -> bool:
	## Для подсказки в HUD: приземлимся ли чисто, если коснёмся земли сейчас
	if not airborne or bailed:
		return true
	if _trick_t > 0.0 and 1.0 - _trick_t / _trick_dur < TRICK_DONE:
		return false
	var off := absf(wrapf(_air_yaw, -PI * 0.5, PI * 0.5))
	return off < LAND_TOLERANCE - 0.3 or off > PI - LAND_TOLERANCE


func charge_ratio() -> float:
	return _charge / MAX_CHARGE if _charging else 0.0


func get_balance() -> float:
	return _balance if _manual else NAN


func set_battery(value: float) -> void:
	battery = clampf(value, 0.0, 1.0)
	_low_warned = battery < 0.15


func on_npc_hit(kind: String, strength: float) -> void:
	## Столкновение с пешеходом/лошадью/машиной. strength — насколько больно.
	if bailed:
		return
	if absf(speed) > 3.5 or strength > 1.5 or airborne:
		speed *= 0.2
		velocity *= 0.2
		_bail()
		Game.npc_hit.emit(kind)
	else:
		speed *= 0.3


func _drain(amount: float) -> void:
	var was := battery
	battery = maxf(0.0, battery - amount)
	if battery < 0.15 and not _low_warned:
		_low_warned = true
		Game.trick_popup.emit("Батарея садится!")
	if was > 0.0 and battery <= 0.0:
		Game.trick_popup.emit("Батарея на нуле")
		battery_empty.emit()


func respawn() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	speed = 0.0
	bailed = false
	_manual = false
	up_direction = Vector3.UP
	_ground_n = Vector3.UP
	_heading_yaw = global_rotation.y
	_reset_pose()
	Game.set_slowmo(false)
	Game.combo_drop()


# ---------- Цикл ----------

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart") or global_position.y < -30.0:
		respawn()

	var steer := Input.get_axis("turn_right", "turn_left")
	var throttle := Input.get_axis("brake", "push")

	if bailed:
		_bail_timer -= delta
		steer = 0.0
		throttle = -1.0
		if _bail_timer <= 0.0:
			bailed = false
			_reset_pose()

	var jd := Input.is_action_pressed("jump")
	_jump_edge = jd and not _jump_down
	_jump_down = jd

	var on_floor := is_on_floor()
	if on_floor:
		_ground_n = get_floor_normal()
		if not _was_on_floor:
			_on_land()
		airborne = false
		_ground(delta, steer, throttle)
	else:
		if _was_on_floor:
			_on_takeoff()
		airborne = true
		_air(delta, steer)

	move_and_slide()

	# Влетели в препятствие — скорость гаснет
	if is_on_floor() and is_on_wall():
		var real := get_real_velocity().length()
		if real + 1.5 < absf(speed):
			speed = signf(speed) * real

	_update_heading()
	_was_on_floor = on_floor
	_animate(delta)


func _ground(delta: float, steer: float, throttle: float) -> void:
	# Касание ребра коробки даёт кривую нормаль — тогда «верх» не трогаем
	up_direction = _ground_n if _ground_n.y > 0.6 else Vector3.UP
	floor_max_angle = GROUND_MAX

	_manual_and_grace(delta)
	if _manual:
		throttle = 0.0

	var fwd := _plane_forward(_ground_n)
	# Гравитация вдоль склона — разгоняет вниз, тормозит вверх
	var g_t := (Vector3.DOWN * gravity).slide(_ground_n)
	speed += g_t.dot(fwd) * delta

	var flatness := clampf(_ground_n.y, 0.0, 1.0)
	battery = maxf(0.0, battery - idle_drain * delta)
	if throttle > 0.0 and not bailed:
		if battery > 0.0:
			# Мотор: плавная тяга, слабеет к максималке и на разряженной батарее
			var power := clampf(0.35 + battery * 1.3, 0.0, 1.0)
			var top := max_speed * power
			if speed < top:
				speed = minf(top, speed + push_accel * throttle * flatness * (1.0 - speed / (top + 0.01) * 0.5) * delta)
			_drain(battery_drain * throttle * delta)
		elif speed < kick_max_speed:
			# Батарея сдохла — толкаемся ногой
			speed = minf(kick_max_speed, speed + kick_accel * throttle * flatness * delta)
			_push_anim += delta * 7.0
	elif throttle < 0.0:
		speed = move_toward(speed, 0.0, brake_force * -throttle * delta)
	else:
		speed = move_toward(speed, 0.0, rolling_friction * delta)
	speed = clampf(speed, -max_speed * 1.5, max_speed * 1.5)

	var turn_factor := clampf(absf(speed) / 4.0, 0.3, 1.0)
	rotate_y(steer * turn_speed * turn_factor * delta)
	fwd = _plane_forward(_ground_n)
	velocity = fwd * speed

	# Олли: нажал — приседаешь (до MAX_CHARGE), отпустил — прыжок.
	# Короткое нажатие = обычный прыжок, удержание = выше.
	if _jump_edge and not bailed:
		_charging = true
		_charge = 0.0
	if _charging:
		_charge = minf(MAX_CHARGE, _charge + delta)
		if not Input.is_action_pressed("jump") or _charge >= MAX_CHARGE:
			_charging = false
			var k := 1.0 + 0.4 * (_charge / MAX_CHARGE)
			# На склоне прыгаем от поверхности, у края бордюра — строго вверх
			if _ground_n.y > 0.75:
				velocity += _ground_n * jump_velocity * k
			else:
				velocity.y = maxf(velocity.y, 0.0) + jump_velocity * k
			_manual = false            # олли из мануала — комбо продолжается
			_grace = 0.0
			floor_snap_length = 0.0


func _air(delta: float, steer: float) -> void:
	up_direction = Vector3.UP
	floor_max_angle = LAND_MAX
	velocity.y -= gravity * delta
	if not bailed:
		# Крутимся, только если руль нажат уже в воздухе — удержание A/D
		# с земли не закручивает случайно.
		if absf(steer) < 0.1:
			_spin_input = true
		if _spin_input and absf(steer) > 0.1:
			_air_yaw += steer * air_spin_speed * delta
		else:
			var target := roundf(_air_yaw / PI) * PI
			_air_yaw = move_toward(_air_yaw, target, AUTO_ALIGN * delta)

	if Input.is_action_just_pressed("trick") and _trick_t <= 0.0 and not bailed:
		var kind := "none"
		if Input.is_action_pressed("push"):
			kind = "forward"
		elif Input.is_action_pressed("brake"):
			kind = "back"
		elif absf(steer) > 0.1:
			kind = "side"
		var t: Dictionary = TRICKS[kind]
		_trick_kind = kind
		_trick_dur = t.dur
		_trick_t = t.dur
		Game.combo_add(t.name, t.points)

	Game.set_slowmo(Input.is_action_pressed("slowmo") and not bailed)


func _manual_and_grace(delta: float) -> void:
	if bailed:
		return
	if _manual:
		_balance_vel += (randf_range(-1.0, 1.0) * 4.0 + _balance * 2.2 - Input.get_axis("brake", "push") * 6.0) * delta
		_balance += _balance_vel * delta
		_balance_vel *= 0.98
		Game.combo_add_points(90.0 * delta)
		if absf(_balance) > 1.0:
			_bail()
		elif Input.is_action_just_pressed("manual"):
			_manual = false
			Game.combo_bank()
	elif _grace > 0.0:
		_grace -= delta
		if Input.is_action_just_pressed("manual"):
			_start_manual()
		elif _grace <= 0.0:
			Game.combo_bank()
	elif Input.is_action_just_pressed("manual") and absf(speed) > 2.0:
		_start_manual()


# ---------- Взлёт / приземление ----------

func _on_takeoff() -> void:
	_air_yaw = 0.0
	_charging = false
	_spin_input = absf(Input.get_axis("turn_right", "turn_left")) < 0.1
	_grace = 0.0
	if _manual:
		_manual = false
	up_direction = Vector3.UP
	# Вылет с вёрта: убираем снос на площадку и чуть подталкиваем обратно,
	# чтобы райдер вернулся на склон.
	if _ground_n.y < 0.4:
		var nh := Vector3(_ground_n.x, 0.0, _ground_n.z).normalized()
		var into := velocity.dot(-nh)
		if into > 0.0:
			velocity += nh * into
		velocity += nh * 0.6


func _on_land() -> void:
	floor_snap_length = 0.5
	Game.set_slowmo(false)
	var n := _ground_n
	var v := velocity.slide(n)
	var spd := v.length()
	var body_yaw := global_rotation.y + _air_yaw
	var half_turns := roundi(_air_yaw / PI)
	# Почти законченный трюк докручиваем, а не роняем
	if _trick_t > 0.0 and 1.0 - _trick_t / _trick_dur >= TRICK_DONE:
		_trick_t = 0.0
	var clean := _trick_t <= 0.0 and not bailed

	var dir := Vector3.ZERO
	if spd > 0.6:
		dir = _heading_from_plane_dir(v / spd, n)
	elif n.y < 0.9:
		dir = Vector3(n.x, 0.0, n.z).normalized()   # почти стоим — лицом вниз по склону

	if dir != Vector3.ZERO:
		var vel_yaw := atan2(-dir.x, -dir.z)
		var diff := wrapf(body_yaw - vel_yaw, -PI, PI)
		if absf(diff) < LAND_TOLERANCE:
			rotation.y = vel_yaw
			speed = spd
		elif absf(diff) > PI - LAND_TOLERANCE:
			rotation.y = vel_yaw + PI
			speed = -spd
		else:
			clean = false
			rotation.y = vel_yaw
			speed = spd * 0.4
	else:
		rotation.y = body_yaw
		speed = 0.0

	_air_yaw = 0.0
	if not clean:
		_bail()
		return
	if half_turns != 0:
		Game.combo_add("Разворот %d" % (absi(half_turns) * 180), 120 * absi(half_turns))
	_reset_pose()
	if Game.has_combo():
		_grace = land_grace


func _start_manual() -> void:
	_manual = true
	_grace = 0.0
	_balance = randf_range(-0.15, 0.15)
	_balance_vel = 0.0
	Game.combo_add("Мануал", 100)


func _bail() -> void:
	bailed = true
	_manual = false
	_bail_timer = 1.3
	_trick_t = 0.0
	_air_yaw = 0.0
	Game.set_slowmo(false)
	Game.combo_drop()
	Game.trick_popup.emit("ПАДЕНИЕ!")
	if _pose:
		_pose.rotation = Vector3(0.0, 0.0, 1.35)


func _reset_pose() -> void:
	_air_yaw = 0.0
	_trick_t = 0.0
	_trick_kind = ""
	if _pose:
		_pose.rotation = Vector3.ZERO
		_deck.rotation = Vector3.ZERO
		_bars.rotation = Vector3.ZERO


# ---------- Геометрия склона ----------

func _plane_forward(n: Vector3) -> Vector3:
	## Переносит горизонтальный курс тела на плоскость склона
	var fh := -global_basis.z
	fh.y = 0.0
	fh = fh.normalized()
	var nh := Vector3(n.x, 0.0, n.z)
	if nh.length() < 0.001:
		return fh
	nh = nh.normalized()
	var side := Vector3.UP.cross(nh)
	var uphill := (Vector3.UP - n * n.y).normalized()
	return (side * fh.dot(side) + uphill * -fh.dot(nh)).normalized()


func _heading_from_plane_dir(d: Vector3, n: Vector3) -> Vector3:
	## Обратное: направление на склоне → горизонтальный курс
	var nh := Vector3(n.x, 0.0, n.z)
	if nh.length() < 0.001:
		var h := Vector3(d.x, 0.0, d.z)
		return h.normalized() if h.length() > 0.001 else Vector3.ZERO
	nh = nh.normalized()
	var side := Vector3.UP.cross(nh)
	var uphill := (Vector3.UP - n * n.y).normalized()
	return (side * d.dot(side) - nh * d.dot(uphill)).normalized()


func _update_heading() -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if airborne:
		if hv.length() > 3.0:
			_heading_yaw = atan2(-hv.x, -hv.z)
	else:
		_heading_yaw = global_rotation.y + (PI if speed < -0.5 else 0.0)


# ---------- Анимация ----------

func _animate(delta: float) -> void:
	if _pose == null:
		return
	# Наклон под поверхность
	var target_up := Vector3.UP if airborne else _ground_n
	var local_up := (global_basis.inverse() * target_up).normalized()
	var q := Quaternion(Vector3.UP, local_up)
	var k := 4.0 if airborne else 16.0
	_align.quaternion = _align.quaternion.slerp(q, clampf(k * delta, 0.0, 1.0))
	var cur_up := _align.quaternion * Vector3.UP
	_align.position = Vector3.UP * RADIUS - cur_up * RADIUS

	if bailed:
		return

	_pose.rotation.y = _air_yaw if airborne else 0.0

	if _trick_t > 0.0:
		_trick_t = maxf(0.0, _trick_t - delta)
		var p := 1.0 - _trick_t / _trick_dur
		var a := ease(p, -2.0) * TAU
		match _trick_kind:
			"forward": _pose.rotation.x = -a
			"back": _pose.rotation.x = a
			"side": _bars.rotation.y = a
			"none": _deck.rotation.y = a
		# Ноги отрываются от деки на трюке
		var kick := sin(p * PI)
		_legs[0].rotation.x = -0.9 * kick
		_legs[1].rotation.x = 0.7 * kick
		if _trick_t <= 0.0:
			_pose.rotation.x = 0.0
			_deck.rotation.y = 0.0
			_bars.rotation.y = 0.0
	elif _manual:
		_pose.rotation.x = 0.35 + _balance * 0.35
		_pose.rotation.z = _balance * 0.25
	else:
		_pose.rotation.x = lerpf(_pose.rotation.x, 0.0, 10.0 * delta)
		_pose.rotation.z = lerpf(_pose.rotation.z, -Input.get_axis("turn_right", "turn_left") * 0.18 * clampf(absf(speed) / 8.0, 0.0, 1.0), 6.0 * delta)
		# Толчок ногой
		var kicking := battery <= 0.0 and Input.is_action_pressed("push") and not airborne
		var push := sin(_push_anim) if kicking else 0.0
		_legs[1].rotation.x = lerpf(_legs[1].rotation.x, push * 0.7, 12.0 * delta)
		_legs[0].rotation.x = lerpf(_legs[0].rotation.x, 0.0, 12.0 * delta)
	# Присед в воздухе
	var crouch := -0.12 if airborne else -0.22 * charge_ratio()
	_rider.position.y = lerpf(_rider.position.y, crouch, 12.0 * delta)


# ---------- Модель ----------

func _build_body() -> void:
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	col.shape = sphere
	col.position.y = RADIUS
	add_child(col)

	_align = Node3D.new()
	_align.name = "Align"
	add_child(_align)
	_pose = Node3D.new()
	_pose.name = "Pose"
	_pose.position.y = 0.02
	_align.add_child(_pose)

	var parts := RiderModel.build(_pose)
	_deck = parts.deck
	_bars = parts.bars
	_rider = parts.rider
	_legs = parts.legs
	_arms = parts.arms
