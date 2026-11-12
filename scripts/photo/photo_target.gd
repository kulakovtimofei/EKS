class_name PhotoTarget
extends Node3D
## Объект, который стоит сфотографировать. Добавь как дочерний узел
## к чему угодно на уровне и задай название и цену.

@export var title := "Что-то странное"
@export var points := 500
@export var radius := 1.0         # примерный размер — для оценки «крупности» в кадре
@export var once := true          # засчитывается только один раз
@export var max_distance := 0.0   # 0 — по умолчанию из фото-режима; для далёких целей (Этна) — больше

var captured := false


func _ready() -> void:
	add_to_group("photo_target")
