class_name Hud
extends CanvasLayer
## Интерфейс: счёт, комбо, шкала фокуса, баланс мануала, видоискатель,
## всплывающие названия трюков и эффект замедления. Собирается кодом.

const SLOWMO_SHADER := preload("res://shaders/slowmo.gdshader")

var player: Scooter

var _score: Label
var _combo: Label
var _combo_pts: Label
var _focus: ProgressBar
var _balance: ProgressBar
var _speed: Label
var _battery: ProgressBar
var _battery_lbl: Label
var _prompt: Label
var _land_hint: Label
var _charge: ProgressBar
var _popups: Control
var _viewfinder: Control
var _flash: ColorRect
var _photo_card: Label
var _fx: ColorRect
var _fx_mat: ShaderMaterial
var _fx_target := 0.0
var _fx_value := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Game.score_changed.connect(func(t: int) -> void: _score.text = "%d" % t)
	Game.combo_changed.connect(_on_combo)
	Game.combo_banked.connect(func(t: int) -> void: _popup("+%d" % t, Color("39ff14"), 64))
	Game.combo_dropped.connect(func() -> void: _popup("КОМБО ПОТЕРЯНО", Color("ff3030"), 40))
	Game.trick_popup.connect(func(n: String) -> void: _popup(n, Color("ffe600"), 44))
	Game.focus_changed.connect(func(v: float) -> void: _focus.value = v)
	Game.prompt_changed.connect(func(t: String) -> void: _prompt.text = t)
	Game.slowmo_changed.connect(func(on: bool) -> void: _fx_target = 1.0 if on else 0.0)


func connect_photo(photo: PhotoMode) -> void:
	photo.viewfinder_changed.connect(func(on: bool) -> void: _viewfinder.visible = on)
	photo.photo_scored.connect(_on_photo)


func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.001)
	_fx_value = move_toward(_fx_value, _fx_target, real_dt * 4.0)
	_fx_mat.set_shader_parameter("intensity", _fx_value)
	if player:
		_speed.text = "%d км/ч" % int(absf(player.speed) * 3.6)
		_battery.value = player.battery
		_battery_lbl.text = "БАТАРЕЯ %d%%" % int(round(player.battery * 100.0)) if player.battery > 0.0 else "БАТАРЕЯ 0% — толкайся ногой или найди другой самокат"
		var low := player.battery < 0.15
		var blink := low and int(Time.get_ticks_msec() / 300) % 2 == 0
		(_battery.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color("ff3030") if low else Color("39ff14")
		_battery_lbl.modulate.a = 0.35 if blink else 1.0
		var show_hint := player.airborne and not player.bailed
		_land_hint.visible = show_hint
		if show_hint:
			var ok := player.landing_ok()
			_land_hint.text = "ПРИЗЕМЛЕНИЕ ✓" if ok else "ДОКРУТИ! ✗"
			_land_hint.add_theme_color_override("font_color", Color("5dffb0") if ok else Color("ff4a7a"))
		var ch := player.charge_ratio()
		_charge.visible = ch > 0.0
		_charge.value = ch
		var b := player.get_balance()
		_balance.visible = not is_nan(b)
		if _balance.visible:
			_balance.value = b


func _on_combo(tricks: PackedStringArray, pts: int, mult: int) -> void:
	if tricks.is_empty():
		_combo.text = ""
		_combo_pts.text = ""
		return
	var shown := tricks.slice(maxi(0, tricks.size() - 4))
	_combo.text = " + ".join(shown)
	_combo_pts.text = "%d × %d" % [pts, mult]


func _on_photo(r: Dictionary) -> void:
	_flash.modulate.a = 1.0
	create_tween().set_ignore_time_scale().tween_property(_flash, "modulate:a", 0.0, 0.35)
	if r.points > 0:
		_photo_card.text = "ФОТО: %s — %s\n+%d%s" % [r.title, r.grade, r.points, "  (снято в трюке ×2!)" if r.get("style", false) else ""]
	else:
		_photo_card.text = "ФОТО: Ничего интересного в кадре"
	_photo_card.modulate.a = 1.0
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_interval(2.0)
	tw.tween_property(_photo_card, "modulate:a", 0.0, 0.5)


func _popup(text: String, color: Color, size: int) -> void:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("1a2a8a"))
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_shadow_color", Color(1.0, 0.4, 0.95, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 4)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.position = Vector2(-300, -120 + randf_range(-30, 30))
	l.size = Vector2(600, 80)
	l.pivot_offset = l.size * 0.5
	l.rotation = randf_range(-0.15, 0.15)
	l.scale = Vector2(0.3, 0.3)
	_popups.add_child(l)
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(l, "scale", Vector2.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.08)
	tw.tween_interval(0.5)
	tw.parallel().tween_property(l, "position:y", l.position.y - 60, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


# ---------- Сборка ----------

func _build() -> void:
	_fx = ColorRect.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = SLOWMO_SHADER
	_fx.material = _fx_mat
	add_child(_fx)

	_score = _label("0", 56, Color.WHITE)
	_score.position = Vector2(24, 12)
	add_child(_score)

	_speed = _label("0 км/ч", 26, Color("00e5ff"))
	_speed.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_speed.position = Vector2(-200, -56)
	add_child(_speed)

	_combo = _label("", 26, Color("ffe600"))
	_combo.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo.position = Vector2(-450, -120)
	_combo.size = Vector2(900, 40)
	add_child(_combo)

	_combo_pts = _label("", 36, Color("ff2bd6"))
	_combo_pts.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_combo_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_pts.position = Vector2(-200, -80)
	_combo_pts.size = Vector2(400, 50)
	add_child(_combo_pts)

	var focus_lbl := _label("ФОКУС [Shift]", 18, Color("ff2bd6"))
	focus_lbl.position = Vector2(26, 82)
	add_child(focus_lbl)
	_focus = _bar(Color("ff2bd6"), 0.0, 1.0)
	_focus.position = Vector2(24, 108)
	_focus.size = Vector2(240, 14)
	_focus.value = Game.focus
	add_child(_focus)

	_battery_lbl = _label("БАТАРЕЯ", 18, Color("39ff14"))
	_battery_lbl.position = Vector2(26, 130)
	add_child(_battery_lbl)
	_battery = _bar(Color("39ff14"), 0.0, 1.0)
	_battery.position = Vector2(24, 156)
	_battery.size = Vector2(240, 14)
	add_child(_battery)

	_prompt = _label("", 28, Color.WHITE)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-400, 60)
	_prompt.size = Vector2(800, 40)
	add_child(_prompt)

	_land_hint = _label("", 30, Color.WHITE)
	_land_hint.set_anchors_preset(Control.PRESET_CENTER)
	_land_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_land_hint.position = Vector2(-200, 100)
	_land_hint.size = Vector2(400, 40)
	_land_hint.visible = false
	add_child(_land_hint)

	_charge = _bar(Color("7ff6ff"), 0.0, 1.0)
	_charge.set_anchors_preset(Control.PRESET_CENTER)
	_charge.position = Vector2(-60, 120)
	_charge.size = Vector2(120, 10)
	_charge.visible = false
	add_child(_charge)

	_balance = _bar(Color("39ff14"), -1.0, 1.0)
	_balance.set_anchors_preset(Control.PRESET_CENTER)
	_balance.position = Vector2(-150, 150)
	_balance.size = Vector2(300, 12)
	_balance.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	_balance.visible = false
	add_child(_balance)

	_popups = Control.new()
	_popups.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popups)

	_viewfinder = _build_viewfinder()
	_viewfinder.visible = false
	add_child(_viewfinder)

	_flash = ColorRect.new()
	_flash.color = Color.WHITE
	_flash.modulate.a = 0.0
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_photo_card = _label("", 28, Color.WHITE)
	_photo_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_photo_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_photo_card.position = Vector2(-620, 20)
	_photo_card.size = Vector2(600, 90)
	_photo_card.modulate.a = 0.0
	add_child(_photo_card)

	var help := _label("W/S газ-тормоз · A/D руль/вращение · Пробел прыжок (держи — выше) · J трюк (+направление) · K мануал · Shift замедление · F/ПКМ фото · E пересесть · R рестарт", 16, Color(1, 1, 1, 0.7))
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(20, -32)
	add_child(help)


func _build_viewfinder() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := Color(1, 1, 1, 0.9)
	# Уголки рамки
	for corner in [Vector2(0.15, 0.15), Vector2(0.85, 0.15), Vector2(0.15, 0.85), Vector2(0.85, 0.85)]:
		var sx := 1.0 if corner.x < 0.5 else -1.0
		var sy := 1.0 if corner.y < 0.5 else -1.0
		var h := ColorRect.new()
		h.color = c
		h.anchor_left = corner.x; h.anchor_right = corner.x
		h.anchor_top = corner.y; h.anchor_bottom = corner.y
		h.offset_left = 0.0 if sx > 0 else -60.0
		h.offset_right = 60.0 if sx > 0 else 0.0
		h.offset_top = 0.0 if sy > 0 else -4.0
		h.offset_bottom = 4.0 if sy > 0 else 0.0
		root.add_child(h)
		var v := ColorRect.new()
		v.color = c
		v.anchor_left = corner.x; v.anchor_right = corner.x
		v.anchor_top = corner.y; v.anchor_bottom = corner.y
		v.offset_left = 0.0 if sx > 0 else -4.0
		v.offset_right = 4.0 if sx > 0 else 0.0
		v.offset_top = 0.0 if sy > 0 else -60.0
		v.offset_bottom = 60.0 if sy > 0 else 0.0
		root.add_child(v)
	var cross := _label("+", 48, c)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-14, -36)
	root.add_child(cross)
	var rec := _label("● REC  отпусти, чтобы снять", 22, Color("ff3030"))
	rec.anchor_left = 0.15; rec.anchor_top = 0.15
	rec.offset_left = 12; rec.offset_top = 12
	root.add_child(rec)
	return root


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("0b1a4a"))
	l.add_theme_constant_override("outline_size", 7)
	l.add_theme_color_override("font_shadow_color", Color(0.3, 0.9, 1.0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(color: Color, min_v: float, max_v: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = min_v
	b.max_value = max_v
	b.step = 0.0
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(8)
	fill.border_width_top = 2
	fill.border_color = color.lightened(0.6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.1, 0.3, 0.55)
	bg.set_corner_radius_all(8)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.75, 0.9, 1.0, 0.8)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	return b
