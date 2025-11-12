extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func _on__pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/main_scene.tscn")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scene/menu.tscn")


func _on__pressed_2():
	get_tree().change_scene_to_file("res://Scene/main_scene2.tscn")


func _on__pressed_3():
		get_tree().change_scene_to_file("res://Scene/main_scene3.tscn")


func _on__pressed_4():
	pass # Replace with function body.


func _on__pressed_5():
	pass # Replace with function body.


func _on__pressed_6():
	pass # Replace with function body.


func _on__pressed_7():
	pass # Replace with function body.


func _on__pressed_8():
	pass # Replace with function body.


func _on__pressed_9():
	pass # Replace with function body.
