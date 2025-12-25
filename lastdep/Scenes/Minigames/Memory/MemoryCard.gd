# MemoryCard.gd
extends Button

@export var card_value: int = 0
@export var is_flipped: bool = false
@export var is_matched: bool = false

var front_texture: Texture2D
var back_texture: Texture2D

func _ready():
	update_appearance()

func setup(value: int, front: Texture2D, back: Texture2D):
	card_value = value
	front_texture = front
	back_texture = back
	update_appearance()

func flip(show_front: bool):
	is_flipped = show_front
	update_appearance()

func mark_matched():
	is_matched = true
	disabled = true
	modulate = Color(0.5, 0.5, 0.5, 0.7)

func update_appearance():
	if is_flipped:
		icon = front_texture
	else:
		icon = back_texture
	
	if is_matched:
		disabled = true
