extends CharacterBody3D

const cTapTime = 0.2;
const cDashTime = 0.14;

const cMaxMoveSpeed = 4.0;
const cMaxSprintSpeed = 7.5;
const cGroundAcceleration = 15.0;
const cGroundFriction = 50.0;

const cDashSpeed = 20.0;
const cJumpImpulse = 5.0;
const cGrindSpeed = 11.0;

const cCameraBaseFOV = 75.0;
const cCameraDashFOV = +10.0;

var mCamera : Camera3D;
## Stores pitch & yaw
var mCameraForwardAngle := Vector2.ZERO;
## Actual forward direction pulled from forward angle
var mCameraForwardDirection := Vector2.ZERO;
## Camera offset of what we're following
var mCameraFollowOffset := Vector3.ZERO;

var mCameraFollowOffsetBlended := Vector3.ZERO;

var mInputVector : Vector2 = Vector2(0, 0);

var mSprintState : FrameVar.AsBool = FrameVar.AsBool.new(false);
var mSprintPressTime : float = 0.0;

var mJumpState : FrameVar.AsBool = FrameVar.AsBool.new(false);
var mJumpNextPhysicsFrame : bool = false;

var mDashing : bool = false;
var mDashingTime : float = 0.0;
var mDashingDirection : Vector2 = Vector2(0, 0);

var cFlatMotionBias : float = 0.015;
var cStairPenetrationBias : float = 0.05;
var cStairMaxHeight : float = 0.4;

# Flattened move speed, motion XZ may actually be less than this due to slopes.
var mFlatMotion : Vector2 = Vector2(0, 0);
var mFullMotion : Vector3 = Vector3(0, 0, 0);
var mFloorNormal : Vector3 = Vector3(0, 1, 0);

var mOnGround : bool = false;

var mWasDashing := bool(false);
var mWasGrinding := bool(false);

var mGrinding : bool = false;
var mGrindingDirection : int = 0;
var mGrindingLastT : float = 0;
var mGrindingNode : DP_PathNode = null;
var mGrindJuiceTimer : float = 0;
var mDisableSpeedLimitUntilGround : bool = false;


var mModelNode : PlayerTest8ModelObject;
var mModelRotationOffset : Quaternion;
var mModelUpdateTimer : float = 0.0;

## Stabilizers for smoothing out motion. Jumps in motion are added to these and then blended out over time.
var mStablizerOffsetCamera := Vector3(0, 0, 0);			## Stabilizer for camera position
var mStablizerOffsetModel := Vector3(0, 0, 0);			## Stabilizer for model position
var mStabilizerRotateCamera := Vector4(0, 0, 0, 0); 	## Stabilizer for camera rotation

@export
var mAssetJuice : PackedScene;
@export
var mAssetJuiceDash : PackedScene;

func clampInputs() -> void:
	mCameraForwardAngle.x = clamp(mCameraForwardAngle.x, deg_to_rad(-100.0), deg_to_rad(100.0));

func _ready() -> void:
	mCamera = get_node("Camera3D") as Camera3D;
	mModelNode = get_node("CharacterModel") as PlayerTest8ModelObject;
	assert(mCamera != null);
	assert(mModelNode != null);
	
	mModelRotationOffset = mModelNode.quaternion;
	return

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseMotion):
		const rotationSpeed = PI / 180.0 * 0.5; #todo: make 0.5 sensitivity value
		mCameraForwardAngle.y -= event.screen_relative.x * rotationSpeed;
		mCameraForwardAngle.x -= event.screen_relative.y * rotationSpeed;
		clampInputs();
	elif (event.is_action("action_sprint")):
		if (event.is_pressed() and not event.is_echo()):
			mSprintState.updateValue(true);
			mSprintPressTime = 0.0;
		elif (event.is_released()):
			mSprintState.updateValue(false);
	elif (event.is_action("action_jump")):
		if (event.is_pressed() and not event.is_echo()):
			mJumpState.updateValue(true);
		elif (event.is_released()):
			mJumpState.updateValue(false);
	return

func queue_remote_free(node : Node) -> void:
	node.queue_free();

func _process(delta: float) -> void:
	# Update the forward direction
	mCameraForwardDirection = Vector2.UP.rotated(-mCameraForwardAngle.y);
	
	var forward := Vector3.FORWARD \
		.rotated(Vector3.RIGHT, mCameraForwardAngle.x) \
		.rotated(Vector3.UP, mCameraForwardAngle.y);
	
	var cameraCenterPosition := Vector3(0, 1, 0) + mStablizerOffsetCamera;
	mCamera.position = -forward * 4 + cameraCenterPosition;
	mCamera.rotation = Vector3(mCameraForwardAngle.x, mCameraForwardAngle.y, 0);

	# Blend in mCameraFollowOffsetBlended
	var smoothWeightC := 1.0 - exp(-8.0 * delta);
	mCameraFollowOffsetBlended = mCameraFollowOffsetBlended.lerp(mCameraFollowOffset, smoothWeightC);
	
	# Move the camera towards mCameraFollowOffset, but limit it to a plane behind the player
	var cameraPositionLimit := Plane(-forward, -forward * 2 + cameraCenterPosition);
	var limitPoint : Variant = cameraPositionLimit.intersects_segment(mCamera.position, mCamera.position + mCameraFollowOffsetBlended);
	if limitPoint != null:
		mCamera.position = limitPoint;
	else:
		mCamera.position += mCameraFollowOffsetBlended;
		
	# Now rotate towards mCameraFollowOffset
	mCamera.transform = mCamera.transform.looking_at(cameraCenterPosition + mCameraFollowOffsetBlended, Vector3.UP);
	
	# Limit the camera to a cone behind the player
	var cameraLocalForward := mCamera.transform.basis * Vector3.FORWARD;
	var cameraPositionCone := -(mCamera.position - cameraCenterPosition);
	var cameraPositionConeLen := cameraPositionCone.length();
	var cameraPositionConeAngle := cameraLocalForward.angle_to(cameraPositionCone / cameraPositionConeLen); # forward here needs to be the angle of the camera
	var cameraPositionConeAngleOver : float = max(0.0, cameraPositionConeAngle / deg_to_rad(mCamera.fov * 0.5) - 1.0);
	#var cameraPositionConeAngleOver : float = 1.0;
	var cameraPositionFinalCone := cameraLocalForward.lerp(cameraPositionCone / cameraPositionConeLen, max(0.0, 1.0 - cameraPositionConeAngleOver));
	mCamera.position = cameraCenterPosition - cameraPositionFinalCone * cameraPositionConeLen;
		
	# Limit the distance of the camera from the player
	var cameraPositionVVec := (mCamera.position - cameraCenterPosition);
	var cameraPositionVVecLen := cameraPositionVVec.length();
	var cameraPositionVVecMaxLen : float = max(4.0, mCameraFollowOffsetBlended.length() + 0.5);
	if (cameraPositionVVecLen > cameraPositionVVecMaxLen):
		mCamera.position = cameraCenterPosition + cameraPositionVVec.normalized() * cameraPositionVVecMaxLen;
	
	# Now rotate towards mCameraFollowOffset
	mCamera.transform = mCamera.transform.interpolate_with(mCamera.transform.looking_at(cameraCenterPosition + mCameraFollowOffsetBlended, Vector3.UP), 0.7);
	
	# Update the motion logic
	mSprintState.updateProcess();
	if (mSprintState.was_disabled()):
		print("released at %f vs %f" % [mSprintPressTime, cTapTime]);
		
		if (mSprintPressTime < cTapTime):
			mDashing = true;
			mDashingTime = 0.0;
			mDashingDirection = (mInputVector + Vector2(0, -0.001)).rotated(-mCameraForwardAngle.y).normalized();
			
			var juiceNode : Node3D = mAssetJuiceDash.instantiate()
			juiceNode.position = position
			juiceNode.rotation = Vector3(0, (-mDashingDirection).angle_to(Vector2.RIGHT), 0);
			get_parent().add_child(juiceNode) # probably bad
			
			var juiceNode2 : Node3D = mAssetJuice.instantiate()
			juiceNode2.position = position
			juiceNode2.rotation = Vector3(0, (-mDashingDirection).angle_to(Vector2.RIGHT), 0);
			get_parent().add_child(juiceNode2) # probably bad
			
			var dupeNode : Node3D = mModelNode.duplicate(DuplicateFlags.DUPLICATE_USE_INSTANTIATION);
			dupeNode.global_transform = mModelNode.global_transform;
			get_parent().add_child(dupeNode) # probably bad
			#dupeNode.reparent(get_parent());
			
			var timer := Timer.new()
			dupeNode.add_child(timer)
			timer.wait_time = 1/12.0;
			timer.one_shot = true;
			timer.timeout.connect(queue_remote_free.bind(dupeNode));
			timer.start();
			
	elif (mSprintState.is_enabled()):
		mSprintPressTime += delta;
		
	# Update grind viz
	if mGrinding:
		mGrindJuiceTimer += delta;
		if mGrindJuiceTimer > 0.05:
			mGrindJuiceTimer -= 0.05;
			var juiceNode : Node3D = mAssetJuice.instantiate()
			juiceNode.position = position
			juiceNode.rotation = Vector3(0, Vector2(mFullMotion.x, mFullMotion.z).angle_to(Vector2.RIGHT), 0);
			get_parent().add_child(juiceNode) # probably bad
		
	# Update some FOV smooth-outs
	if mGrinding != mWasGrinding:
		mWasGrinding = mGrinding;
		mStabilizerRotateCamera.w += cCameraDashFOV * (-1 if mGrinding else 1);
	if mDashing != mWasDashing:
		mWasDashing = mDashing;
		mStabilizerRotateCamera.w += cCameraDashFOV * (-1 if mDashing else 1);
		
	# Update the jump logic
	mJumpState.updateProcess();
	if (mJumpState.was_enabled()):
		print("jump pressed");
		mJumpNextPhysicsFrame = true;
		
	# Update the camera offsets
	mCamera.fov = cCameraBaseFOV;
	if (mDashing):
		mCamera.fov += cCameraDashFOV;
	elif (mGrinding):
		mCamera.fov += cCameraDashFOV;
	
	mCamera.rotation += Vector3(mStabilizerRotateCamera.x, mStabilizerRotateCamera.y, mStabilizerRotateCamera.z);
	mCamera.fov += mStabilizerRotateCamera.w;
		
	# Update the model
	# Rotation is going to be from the mFlatMotion
	if (mFlatMotion.length_squared() > 0.01):
		mModelNode.rotation = Vector3(0, mFlatMotion.angle_to(Vector2.UP), 0);
		mModelNode.quaternion *= mModelRotationOffset;
	mModelNode.position = mStablizerOffsetModel;
	
	# Smooth out offsets:
	var smoothWeight0 := 1.0 - exp(-8.0 * delta);
	var smoothWeight1 := 1.0 - exp(-16.0 * delta);
	var smoothWeight2 := 1.0 - exp(-40.0 * delta);
	mStablizerOffsetCamera = mStablizerOffsetCamera.lerp(Vector3.ZERO, smoothWeight0);
	mStablizerOffsetModel = mStablizerOffsetModel.lerp(Vector3.ZERO, smoothWeight1);
	mStabilizerRotateCamera = mStabilizerRotateCamera.lerp(Vector4.ZERO, smoothWeight2);
	
	# Animations
	var animationPlayer := mModelNode.get_node("AnimationPlayer") as AnimationPlayer;
	
	if mGrinding:
		animationPlayer.play("anim test 2/Railride");
	else:
		if (mFlatMotion.length_squared() > 0.01):
			if mOnGround:
				var animationSpeed := mFlatMotion.length() / (cMaxSprintSpeed);
				animationPlayer.play("anim test 2/Run1", -1, 2.2 * animationSpeed);
			else:
				animationPlayer.play("anim test 2/Run1", 0.5, 0.0);
		else:
			animationPlayer.play("anim test 2/Idle 1");
		
	# Update animator
	animationPlayer.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;
	const Framerate = 1.0 / 24.0;
	mModelUpdateTimer += delta;
	while (mModelUpdateTimer >= Framerate):
		animationPlayer.advance(Framerate);
		mModelUpdateTimer -= Framerate;
		
	return
	
func _physics_process(delta: float) -> void:
	# Get motion input impulse from the input & camera angle
	mInputVector = Vector2(
		Input.get_axis("move_left", "move_right"),
		-Input.get_axis("move_back", "move_forward")).normalized();
	var rotatedInputVector : Vector2 = mInputVector.rotated(-mCameraForwardAngle.y);
	
	#var floorX : Vector3 = Vector3(1, 0, 0);
	#var floorZ : Vector3 = floorX.cross(mFloorNormal);
	#floorX = floorZ.cross(mFloorNormal);
	#var floorTransform :  = Transform3D(floorX, mFloorNormal, floorZ);
	
	# Extract flat motion from velocity
	mFullMotion = self.velocity;
	mFlatMotion = Vector2(mFullMotion.x, mFullMotion.z);
	
	# Apply next motion
	var possibleNextMotion : Vector2 = mFlatMotion;
	var possibleMaxSpeed : float = cMaxMoveSpeed;
	if (mSprintState.is_enabled()):
		possibleMaxSpeed = cMaxSprintSpeed;
	if (mDisableSpeedLimitUntilGround):
		possibleMaxSpeed = max(possibleMaxSpeed, cGrindSpeed);
	
	if (not mDashing):
		# Calculate both motion accel and friction accel
		var targetDelta : Vector2 = (rotatedInputVector * possibleMaxSpeed) - mFlatMotion;
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
				var juiceNode : Node3D = mAssetJuice.instantiate()
				juiceNode.position = position
				juiceNode.rotation = Vector3(0, mFlatMotion.angle_to(Vector2.RIGHT), 0);
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
	
	# Collision Steps:
	# 1. Do stair checks in the given "flat" motion
	#    1b. Generate Z offset
	# 2. Recombine w/ motion and move & collide normal
	
	var lHasGround : bool = false;
	var lPositionStart : Vector3 = self.position;
	
	# Stair check
	# Set up "flat" motion:
	mFullMotion = Vector3(mFlatMotion.x, 0, mFlatMotion.y);
	# Move with contact:
	self.position = lPositionStart;
	var lCollisionStair0 :  KinematicCollision3D;
	lCollisionStair0 = move_and_collide(mFullMotion * delta, true);
	if (lCollisionStair0 and lCollisionStair0.get_collision_count() > 0):
		self.position = lPositionStart \
			# Move to contact position
			+ lCollisionStair0.get_travel() \
			# Move a bit into the stair
			+ lCollisionStair0.get_travel().normalized() * min(cStairPenetrationBias, lCollisionStair0.get_remainder().length()) \
			# Start above the max stair height
			+ mFloorNormal * (cStairMaxHeight + cFlatMotionBias);
		# Cast downward
		var lCollisionStair1 : KinematicCollision3D; 
		lCollisionStair1 = move_and_collide(-mFloorNormal * cStairMaxHeight, true);
		# We have a stair!
		if (lCollisionStair1 and lCollisionStair1.get_collision_count() > 0):
			# Was there any space to move?
			if (lCollisionStair1.get_travel().length_squared() > 0):
				# Pull the starting position upwards
				var lStairHeight : float = cStairMaxHeight - lCollisionStair1.get_travel().length();
				print("stair height %f" % [lStairHeight]);
				lPositionStart += mFloorNormal * max(0, lStairHeight + cFlatMotionBias);
				# Mark we have ground so we can get our slide onto the stair:
				lHasGround = true;
				
				# Add offset
				mStablizerOffsetCamera -= mFloorNormal * max(0, lStairHeight + cFlatMotionBias);
				mStablizerOffsetModel -= mFloorNormal * max(0, lStairHeight + cFlatMotionBias);
			pass
		pass
	# TODO: Move with contact down stairs when on the ground (ground "glue")
		
	if not lHasGround:
		# Recombine the "flat" motion with the 3D motion
		mFullMotion.y = self.velocity.y;
		# Do gravity
		mFullMotion += self.get_gravity() * delta;
	else:
		# Stop vertical motion
		mFullMotion.y = 0;
	
	# Reset position
	self.position = lPositionStart;

	# Update ground check
	var lCollisionFloor0 : KinematicCollision3D;
	lCollisionFloor0 = move_and_collide(-mFloorNormal * cFlatMotionBias * 2.0, true);
	if (lCollisionFloor0 and lCollisionFloor0.get_collision_count() > 0):
		mOnGround = true;
	else:
		mOnGround = false;
	
	if mOnGround:
		mDisableSpeedLimitUntilGround = false;
		
	# Do grinding
	physicsProcessGrindPaths(delta);
	
	# Do jumping logic
	if mJumpNextPhysicsFrame:
		mJumpNextPhysicsFrame = false;
		if mOnGround:
			mFullMotion.y = cJumpImpulse;
		pass
	
	# Do motion checks now
	self.velocity = mFullMotion;
	move_and_slide();
	
	# Read back resulting motion
	mFullMotion = self.velocity;
	
	if lHasGround:
		print("vertical speed %f" % mFullMotion.y);
	
	return

func physicsProcessGrindPaths(_delta: float) -> void:
	var all_grindpathnodes := get_tree().get_nodes_in_group("grindpaths");
	var started_grinding := bool(false);
	
	if not mGrinding:
		# Find a spot to grind:
		# Find the closest path
		for node in all_grindpathnodes:
			var pathnode := node as DP_PathNode;
			if pathnode:
				var path_t := pathnode.get_closest_parametric(self.position);
				if path_t > 0.0 and path_t < 1.0:
					var path_point := pathnode.get_position_from_t(path_t);
					var path_point_distance := (path_point - self.position).length();
					
					if ((path_point_distance < 0.5) and (not mOnGround) and (mFullMotion.y < 0.0)) or ((path_point_distance < 0.25) and (mFullMotion.y < 1.0)):
						var path_direction := pathnode.get_direction_from_t(path_t).normalized();
						var input_direction := (mInputVector + Vector2(0, -0.001)).rotated(-mCameraForwardAngle.y).normalized();
						var path_facing := path_direction.dot(Vector3(input_direction.x, 0, input_direction.y));
						if abs(path_facing) > 0.25:
							mGrinding = true;
							mGrindingNode = pathnode;
							
							if path_facing > 0.0:
								mGrindingDirection = 1;
							else:
								mGrindingDirection = -1;
						
							started_grinding = true;
						
							print("Starting Grind %d" % mGrindingDirection)
						pass
					pass
				pass
			pass
		pass
	
	if mGrinding:
		# Grinding!
		mOnGround = true; # Force on-ground for this
	
		# Do path-following:	
		if mGrindingNode != null:
			var path_t := mGrindingNode.get_closest_parametric(self.position);
			
			if path_t >= 1.0 and mGrindingDirection > 0:
				mGrindingNode = mGrindingNode.nextNode;
			elif path_t < 0.0 and mGrindingDirection < 0:
				if mGrindingNode.previousNodes.size() > 0:
					mGrindingNode = mGrindingNode.previousNodes[0];
				else:
					mGrindingNode = null;
				pass
			pass
		
		# Do path-motion:
		if mGrindingNode != null:
			var path_t := mGrindingNode.get_closest_parametric(self.position);
			
			# Glue to the path
			var path_point := mGrindingNode.get_position_from_t(clamp(path_t, 0.0, 1.0));
			if (started_grinding):
				mStablizerOffsetCamera += self.position - path_point;
				mStablizerOffsetModel += self.position - path_point;
			self.position = path_point;
			
			# Move along the path
			mFullMotion = mGrindingNode.get_direction_from_t(path_t).normalized() * cGrindSpeed * mGrindingDirection;
			
			# Follow the path ahead
			var future_path_point : Vector3;
			var cLookahead := 0.5 if (mGrindingDirection > 0) else -0.5;
			if (path_t + cLookahead < 0.0) or (path_t + cLookahead > 1.0):
				future_path_point = Vector3.ZERO;
				if mGrindingDirection > 0:
					future_path_point = mGrindingNode.get_position_from_t(1.0);
					if mGrindingNode.nextNode != null:
						future_path_point = mGrindingNode.nextNode.get_position_from_t(path_t + cLookahead - 1.0);
				else:
					future_path_point = mGrindingNode.get_position_from_t(0.0);
					if mGrindingNode.previousNodes.size() > 0 and mGrindingNode.previousNodes[0] != null:
						future_path_point = mGrindingNode.previousNodes[0].get_position_from_t(path_t + cLookahead + 1.0);
				pass
			else:
				future_path_point = mGrindingNode.get_position_from_t(path_t + cLookahead);
			mCameraFollowOffset = future_path_point - self.position;
		
		# Stop grinding when jumping or no node:
		if mJumpNextPhysicsFrame or (mGrindingNode == null) or (mGrindingNode.nextNode == null):
			mGrinding = false;
			mDisableSpeedLimitUntilGround = true;
			mCameraFollowOffset = Vector3.ZERO;
			print("Ending Grind")
			
		pass
		
		
	pass
