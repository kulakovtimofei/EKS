extends Node
## Снимок экрана уровня:
## godot --path . res://tests/screenshot.tscn -- <out.png> [ракурс]
## Ракурсы: start, cathedral, fountain, uzeda, etnea, market

const VIEWS := {
	"start": [Vector3(4, 0.3, 32), 0.0],
	"cathedral": [Vector3(-2, 0.3, 2), -PI * 0.5],
	"fountain": [Vector3(10, 0.3, 4), PI * 0.3],
	"uzeda": [Vector3(20, 0.3, 20), PI],
	"etnea": [Vector3(30, 0.3, -20), -0.25],
	"market": [Vector3(-15, 0.3, 40), PI],
	"lineup": [Vector3(4, 0.3, 30), 0.0],
}


func _ready() -> void:
	add_child((load("res://scenes/levels/catania_duomo.tscn") as PackedScene).instantiate())
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://shot.png"
	var view: Array = VIEWS.get(args[1] if args.size() > 1 else "start", VIEWS.start)
	var player := find_child("Player", true, false) as Scooter
	await get_tree().process_frame
	player.global_position = view[0]
	player.rotation.y = view[1]
	player._heading_yaw = view[1]
	var cam := find_child("Camera", true, false) as ChaseCamera
	cam._yaw = view[1]
	cam.global_position = player.global_position + Vector3(sin(view[1]), 0, cos(view[1])) * 3.6 + Vector3.UP * 1.4
	if args.size() > 1 and args[1] == "lineup":
		cam.set_process(false)
		cam.global_position = player.global_position + Vector3(0, 1.1, 0.4)
		cam.look_at(player.global_position + Vector3(0, 0.8, -3.2))
		cam.fov = 50.0
	if args.size() > 1 and args[1] == "lineup":
		# Типажи толпы в ряд перед камерой, лицом к ней
		var rng := RandomNumberGenerator.new()
		var kinds := ["alt_girl", "grandpa_tweed", "grandpa_cap"]
		for i in kinds.size():
			var n := Node3D.new()
			n.position = player.global_position + Vector3(-1.3 + i * 1.3, -0.3, -3.2)
			n.rotation.y = PI
			add_child(n)
			var parts := NpcCharacters.build(kinds[i], n, rng)
			if i == 0:
				# середина шага: левая нога вперёд, правая рука вперёд
				parts.legs[0].rotation.x = 0.5
				parts.legs[1].rotation.x = -0.5
				parts.arms[0].rotation.x = -0.4
				parts.arms[1].rotation.x = 0.4
		player.visible = false
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
