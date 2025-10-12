extends Node3D

func _on_timer_timeout() -> void:
	queue_free();


func _on_ready() -> void:
	#print("timeout scene ready");
	pass
