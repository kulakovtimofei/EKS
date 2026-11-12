extends Node
## Замер запуска: godot --path . res://tests/startup_timing.tscn

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var ps := load("res://scenes/levels/catania_duomo.tscn") as PackedScene
	var t1 := Time.get_ticks_msec()
	var lvl := ps.instantiate()
	var t2 := Time.get_ticks_msec()
	add_child(lvl)
	var t3 := Time.get_ticks_msec()
	print("TIMING load=%d instantiate=%d add_child(_ready)=%d" % [t1 - t0, t2 - t1, t3 - t2])
	var prev := Time.get_ticks_msec()
	for i in 10:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		print("TIMING frame%d=%d" % [i, now - prev])
		prev = now
	var tt := Time.get_ticks_msec()
	for i in 60:
		await get_tree().process_frame
	print("TIMING avg_frame_60=%d" % ((Time.get_ticks_msec() - tt) / 60))
	var RS := RenderingServer
	print("TIMING objects=%d draw_calls=%d primitives=%d" % [
		RS.get_rendering_info(RS.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RS.get_rendering_info(RS.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RS.get_rendering_info(RS.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	# Эксперименты: что съедает кадр
	var life := lvl.find_child("CityLife", false, false) as Node3D
	for exp in ["web_shadow", "no_npc", "no_shadow", "no_lights"]:
		match exp:
			"web_shadow":
				for l in lvl.find_children("*", "DirectionalLight3D", true, false):
					l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
					l.directional_shadow_max_distance = 30.0
			"no_npc": life.visible = false
			"no_shadow":
				life.visible = true
				for l in lvl.find_children("*", "DirectionalLight3D", true, false): l.shadow_enabled = false
			"no_lights":
				for l in lvl.find_children("*", "OmniLight3D", true, false): l.visible = false
		for i in 10: await get_tree().process_frame
		var t := Time.get_ticks_msec()
		for i in 40: await get_tree().process_frame
		print("TIMING exp %s avg=%d calls=%d" % [exp, (Time.get_ticks_msec() - t) / 40, RS.get_rendering_info(RS.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	var counts := {}
	_count(lvl, counts)
	print("TIMING nodes ", counts)
	for ch in lvl.get_children():
		var c2 := {}
		_count(ch, c2)
		if c2.get("MeshInstance3D", 0) > 30 or c2.get("OmniLight3D", 0) > 0:
			print("TIMING  child %s (%s): %s" % [ch.name, ch.get_class(), c2])
	get_tree().quit()


func _count(n: Node, c: Dictionary) -> void:
	var k := n.get_class()
	if k in ["MeshInstance3D", "OmniLight3D", "SpotLight3D", "Skeleton3D", "GPUParticles3D", "CPUParticles3D", "DirectionalLight3D", "Area3D"]:
		c[k] = c.get(k, 0) + 1
	for ch in n.get_children():
		_count(ch, c)
