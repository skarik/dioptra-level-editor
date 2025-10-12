extends MeshInstance3D

var mInputVector : Vector2;

func _input(event):
	# something
	print(event.as_text());
	return
	
func _physics_process(delta):
	mInputVector = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_back", "move_forward"));
		
	self.position += Vector3(
		mInputVector.x,
		0,
		mInputVector.y) * delta * 4.0;
	
	return
