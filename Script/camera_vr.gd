extends Node
@onready var players := {
	"1": {
		viewport = $HBoxContainer/SubViewportContainer/SubViewport,
		camera = $HBoxContainer/SubViewportContainer/SubViewport/Camera2D
	},
	"2": {
		viewport = $HBoxContainer/SubViewportContainer2/SubViewport,
		camera = $HBoxContainer/SubViewportContainer2/SubViewport/Camera2D
	}
}

# Called when the node enters the scene tree for the first time.
func _ready():
	players["2"].viewport.world_2d = players["1"].viewport.world_2d


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_menu_pressed() -> void:
	MenuMusic.play()
	get_tree().change_scene_to_file("res://Scene/levels.tscn")


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
