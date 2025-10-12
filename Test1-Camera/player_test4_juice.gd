extends Node3D

const cTapTime = 0.2;
const cDashTime = 0.14;

const cMaxMoveSpeed = 4.0;
const cGroundAcceleration = 8.0;
const cGroundFriction = 50.0;

const cDashSpeed = 20.0;

const cCameraBaseFOV = 75.0;
const cCameraDashFOV = +10.0;

var mCamera : Camera3D;
# Stores pitch & yaw
var mForwardAngle : Vector2 = Vector2(0, 0);
# Actual forward direction pulled from forward angle
var mForwardDirection : Vector2 = Vector2(0, 0);

var mInputVector : Vector2 = Vector2(0, 0);

var mSprintState : FrameVar.AsBool = FrameVar.AsBool.new(false);
var mSprintPressTime : float = 0.0;

var mDashing : bool = false;
var mDashingTime : float = 0.0;
var mDashingDirection : Vector2 = Vector2(0, 0);

# Flattened move speed, flattened may actually be less than this due to slopes.
var mFlatMotion : Vector2 = Vector2(0, 0);

@export
var mAssetJuice : PackedScene;

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
	elif (event.is_action("action_sprint")):
		if (event.is_pressed()):
			mSprintState.updateValue(true);
			mSprintPressTime = 0.0;
		elif (event.is_released()):
			mSprintState.updateValue(false);
	return

func _process(delta: float):
	# Update the forward direction
	mForwardDirection = Vector2.UP.rotated(-mForwardAngle.y);
	
	##var forward = Vector3(mForwardDirection.x, 0, mForwardDirection.y);
	var forward = Vector3.FORWARD \
		.rotated(Vector3.RIGHT, mForwardAngle.x) \
		.rotated(Vector3.UP, mForwardAngle.y);
	
	#mCamera.global_position = position - forward * 4 + Vector3(0, 1, 0);
	mCamera.position = -forward * 4 + Vector3(0, 1, 0);
	mCamera.rotation = Vector3(mForwardAngle.x, mForwardAngle.y, 0);
	
	mCamera.fov = cCameraBaseFOV;
	if (mDashing):
		mCamera.fov += cCameraDashFOV;
	
	# Update the motion logic
	mSprintState.updateProcess();
	if (mSprintState.was_disabled()):
		print("released at %f vs %f" % [mSprintPressTime, cTapTime]);
		if (mSprintPressTime < cTapTime):
			print("dashing!");
			mDashing = true;
			mDashingTime = 0.0;
			mDashingDirection = (mInputVector + Vector2(0, -0.001)).normalized();
			
			var juiceNode : Node3D = mAssetJuice.instantiate()
			juiceNode.position = position
			juiceNode.rotation = Vector3(0, mForwardAngle.y + (-mDashingDirection).angle_to(Vector2.RIGHT), 0);
			get_parent().add_child(juiceNode) # probably bad
			
	elif (mSprintState.is_enabled()):
		mSprintPressTime += delta;
	
	return
	
func _physics_process(delta: float):
	mInputVector = Vector2(
		Input.get_axis("move_left", "move_right"),
		-Input.get_axis("move_back", "move_forward"));
	
	var possibleNextMotion : Vector2 = mFlatMotion;
	
	if (not mDashing):
		# Calculate both motion accel and friction accel
		var targetDelta : Vector2 = (mInputVector * cMaxMoveSpeed) - mFlatMotion;
		var targetDeltaLength : float = targetDelta.length();
		var targetDeltaNormalized : Vector2 = targetDelta / max(0.0001, targetDeltaLength);
		var possibleNextMotionAccel : Vector2 = mFlatMotion + targetDeltaNormalized * min(targetDeltaLength, cGroundAcceleration * delta);
		var possibleNextMotionFrict : Vector2 = mFlatMotion + targetDeltaNormalized * min(targetDeltaLength, cGroundFriction * delta);
		
		# Apply friction if the friction is closer to stopping, or the friction is in a different direction than the acceleration
		possibleNextMotion = possibleNextMotionAccel;
		var isBrakingFaster : bool     = possibleNextMotionFrict.length_squared() < possibleNextMotionAccel.length_squared();
		var isChangingDirection : bool = possibleNextMotionFrict.dot(possibleNextMotionAccel) < 0.0;
		
		if (isBrakingFaster or isChangingDirection):
			possibleNextMotion = possibleNextMotionFrict;
			if isChangingDirection:
				print("doing step juice");
				var juiceNode : Node3D = mAssetJuice.instantiate()
				juiceNode.position = position
				juiceNode.rotation = Vector3(0, mForwardAngle.y + mFlatMotion.angle_to(Vector2.RIGHT), 0);
				get_parent().add_child(juiceNode) # probably bad
			
	elif (mDashing):
		# We dash:
		possibleNextMotion = mDashingDirection * lerp(cDashSpeed, (cMaxMoveSpeed + cDashSpeed) * 0.5, mDashingTime / cDashTime);
		# State tracking for the dash:
		mDashingTime += delta;
		if (mDashingTime > cDashTime):
			mDashing = false;
			
	# Use the chosen motion!
	mFlatMotion = possibleNextMotion;
		
	self.position += Vector3(
		mFlatMotion.x,
		0,
		mFlatMotion.y).rotated(Vector3.UP, mForwardAngle.y) * delta;
	
	return
