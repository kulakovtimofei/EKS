class_name RiderSkin
extends Node3D
## Скиннед-модель альтушки (altushka_ps2.glb).
## Базовая поза — анимация pose_anim ("Ride" на самокате, "" — стоя, из рест-позы).
## Поверх неё кости доворачиваются по узлам-пивотам, которые крутит код
## (Scooter или Walker): legs[0]/arms[0] — левая сторона, [1] — правая.
## Плюс rotation.x у пивота = конечность вперёд.

const SCENE_PATH := "res://assets/characters/altushka_ps2.glb"
const LEG_BONES := ["UpperLeg.L", "UpperLeg.R"]
const KNEE_BONES := ["LowerLeg.L", "LowerLeg.R"]
const ARM_BONES := ["UpperArm.L", "UpperArm.R"]

var pose_anim := "Ride"
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var bend_knees := false          # подгибать колено, когда нога уходит назад (ходьба)
var arm_down := 0.0              # опустить руки из A-позы вдоль тела, рад

var _skel: Skeleton3D
var _bones := {}                 # имя -> [индекс, базовый кватернион]


static func available() -> bool:
	return ResourceLoader.exists(SCENE_PATH)


func _ready() -> void:
	var model := (load(SCENE_PATH) as PackedScene).instantiate()
	add_child(model)
	_skel = _find(model, "Skeleton3D") as Skeleton3D
	var ap := _find(model, "AnimationPlayer") as AnimationPlayer
	if ap:
		if pose_anim != "" and ap.has_animation(pose_anim):
			ap.play(pose_anim)
			ap.seek(0.0, true)
		ap.active = false
	if pose_anim == "":
		_skel.reset_bone_poses()
	for b in LEG_BONES + KNEE_BONES + ARM_BONES:
		var idx := _skel.find_bone(b)
		if idx >= 0:
			_bones[b] = [idx, _skel.get_bone_pose_rotation(idx)]
	if arm_down != 0.0:
		for i in 2:
			# L — сводим вниз вокруг оси Z кости в одну сторону, R — в другую
			_rot(ARM_BONES[i], Quaternion(Vector3.FORWARD, arm_down * (-1.0 if i == 0 else 1.0)), true)


func _process(_delta: float) -> void:
	for i in mini(legs.size(), 2):
		var a := legs[i].rotation.x
		_rot(LEG_BONES[i], Quaternion(Vector3.RIGHT, -a))
		if bend_knees:
			_rot(KNEE_BONES[i], Quaternion(Vector3.RIGHT, maxf(0.0, -a) * 1.2))
	for i in mini(arms.size(), 2):
		_rot(ARM_BONES[i], Quaternion(Vector3.RIGHT, -arms[i].rotation.x))


func _rot(bone: String, q: Quaternion, rebase := false) -> void:
	if not _bones.has(bone):
		return
	var e: Array = _bones[bone]
	var r: Quaternion = e[1] * q
	if rebase:
		e[1] = r
	_skel.set_bone_pose_rotation(e[0], r)


static func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f:
			return f
	return null
