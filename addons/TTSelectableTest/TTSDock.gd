@tool
extends Control

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass


func input_makeItem() -> void:
	pass
func input_reset() -> void:
	pass

func _ready() -> void:
#	$ActionHFlow/Button.connect("pressed", self.input_makeItem);
#	$ActionHFlow/Button.connect("pressed", self.input_reset);
#	
#	$ActionHFlow/Button.pressed.connect()
	pass
