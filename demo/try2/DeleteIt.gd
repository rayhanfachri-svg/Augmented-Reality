extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	$"../ARImageSpawner".add_target_scene("Shovel", load("res://models/Sekop.tscn"))
