extends Node3D

var mCamera : Camera3D;
# Stores pitch & yaw
var mForwardAngle : Vector2 = Vector2(0, 0);
# Actual forward direction pulled from forward angle
var mForwardDirection : Vector2 = Vector2(0, 0);

func clampInputs():
	mForwardAngle.x = clamp(mForwardAngle.x, deg_to_rad(-100.0), deg_to_rad(100.0));

func _ready():
	mCamera = get_node("Camera3D") as Camera3D;
	return

func _unhandled_input(event: InputEvent):
	if (event is InputEventMouseMotion):
		const rotationSpeed = PI / 180.0 * 0.5; #todo: make 0.5 sensitivity value
		mForwardAngle.y -= event.screen_relative.x * rotationSpeed;
		mForwardAngle.x -= event.screen_relative.y * rotationSpeed;
		clampInputs();
		
	
	return

func _process(delta: float):
	# Update the forward direction
	mForwardDirection = Vector2.UP.rotated(-mForwardAngle.y);
	
	var forward = Vector3(mForwardDirection.x, 0, mForwardDirection.y);
	
	mCamera.position = position - forward * 4 + Vector3(0, 1, 0);
	mCamera.rotation = Vector3(mForwardAngle.x, mForwardAngle.y, 0);
	
	return
	
func _physics_process(delta: float):
	
	return
