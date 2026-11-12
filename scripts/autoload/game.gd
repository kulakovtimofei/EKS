extends Node
## Глобальное состояние: ввод, комбо, счёт, шкала фокуса и управление временем.
## Зарегистрирован как автозагрузка "Game" (project.godot → [autoload]).

signal score_changed(total: int)
signal combo_changed(tricks: PackedStringArray, points: int, mult: int)
signal combo_banked(total: int)
signal combo_dropped
signal trick_popup(text: String)
signal focus_changed(value: float)
signal slowmo_changed(active: bool)
signal prompt_changed(text: String)       # подсказка над HUD, "" — скрыть
signal npc_hit(kind: String)

const SLOWMO_SCALE := 0.3
const FOCUS_DRAIN := 0.45          # в секунду реального времени
const FOCUS_PER_POINT := 0.0006    # сколько фокуса даёт одно очко комбо

var total_score := 0
var focus := 1.0
var slowmo_active := false

var combo_tricks: PackedStringArray = []
var combo_points := 0.0

# Разные системы просят своё замедление (слоумо, видоискатель);
# побеждает самое сильное.
var _time_requests := {}
var _lowpass_idx := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 900.0
	AudioServer.add_bus_effect(0, lp)
	_lowpass_idx = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, _lowpass_idx, false)


func _process(delta: float) -> void:
	# delta уже умножен на time_scale — возвращаем реальное время
	var real_dt := delta / maxf(Engine.time_scale, 0.001)
	if slowmo_active:
		focus = maxf(0.0, focus - FOCUS_DRAIN * real_dt)
		focus_changed.emit(focus)
		if focus <= 0.0:
			set_slowmo(false)


# ---------- Время ----------

func set_slowmo(on: bool) -> void:
	if on and focus < 0.05:
		on = false
	if on == slowmo_active:
		return
	slowmo_active = on
	request_time_scale("slowmo", SLOWMO_SCALE if on else 1.0)
	slowmo_changed.emit(on)


func request_time_scale(key: String, value: float) -> void:
	if value >= 1.0:
		_time_requests.erase(key)
	else:
		_time_requests[key] = value
	var s := 1.0
	for v in _time_requests.values():
		s = minf(s, v)
	Engine.time_scale = s
	# Звук «под водой» во время замедления
	AudioServer.set_bus_effect_enabled(0, _lowpass_idx, s < 1.0)


# ---------- Комбо ----------

func combo_add(trick_name: String, points: float) -> void:
	# Повтор одного и того же трюка в комбо стоит всё меньше
	var repeats := 0
	for t in combo_tricks:
		if t == trick_name:
			repeats += 1
	var p := points * pow(0.5, repeats)
	combo_tricks.append(trick_name)
	combo_points += p
	trick_popup.emit(trick_name)
	_emit_combo()


func combo_add_points(points: float) -> void:
	if combo_tricks.is_empty():
		return
	combo_points += points
	_emit_combo()


func combo_mult() -> int:
	return maxi(1, combo_tricks.size())


func has_combo() -> bool:
	return not combo_tricks.is_empty()


func combo_bank() -> void:
	if combo_tricks.is_empty():
		return
	var total := int(combo_points) * combo_mult()
	total_score += total
	focus = minf(1.0, focus + total * FOCUS_PER_POINT)
	focus_changed.emit(focus)
	_clear_combo()
	combo_banked.emit(total)
	score_changed.emit(total_score)


func combo_drop() -> void:
	if combo_tricks.is_empty():
		return
	_clear_combo()
	combo_dropped.emit()


func add_score(points: int) -> void:
	total_score += points
	score_changed.emit(total_score)


func _clear_combo() -> void:
	combo_tricks = []
	combo_points = 0.0
	_emit_combo()


func _emit_combo() -> void:
	combo_changed.emit(combo_tricks, int(combo_points), combo_mult())


# ---------- Ввод ----------
# Действия задаются кодом, чтобы project.godot оставался читаемым.
# Если захочешь переназначить в редакторе (Project Settings → Input Map),
# созданное там действие имеет приоритет — здесь оно не перезапишется.

func _setup_input() -> void:
	_add_keys("push", [KEY_W, KEY_UP])
	_add_keys("brake", [KEY_S, KEY_DOWN])
	_add_keys("turn_left", [KEY_A, KEY_LEFT])
	_add_keys("turn_right", [KEY_D, KEY_RIGHT])
	_add_keys("jump", [KEY_SPACE])
	_add_keys("trick", [KEY_J])
	_add_keys("manual", [KEY_K])
	_add_keys("slowmo", [KEY_SHIFT])
	_add_keys("photo", [KEY_F])
	_add_keys("restart", [KEY_R])
	_add_keys("interact", [KEY_E])
	_add_joy_button("interact", JOY_BUTTON_B)
	_add_mouse("photo", MOUSE_BUTTON_RIGHT)

	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("trick", JOY_BUTTON_X)
	_add_joy_button("manual", JOY_BUTTON_Y)
	_add_joy_button("slowmo", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button("photo", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_axis("push", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_axis("brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joy_axis("turn_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("turn_right", JOY_AXIS_LEFT_X, 1.0)


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: MouseButton) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
