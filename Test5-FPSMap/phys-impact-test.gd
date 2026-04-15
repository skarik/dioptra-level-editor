extends RigidBody3D

signal contact_entered(body : Node, normal : Vector3, impulse : Vector3, position : Vector3);

@export
var impact_sfx : AudioStream;

func _init() -> void:
	contact_monitor = true;
	max_contacts_reported = 8;
	#body_entered.connect(_on_body_entered);
	contact_entered.connect(_on_contact);

func _on_contact(body : Node, _normal : Vector3, impulse : Vector3, hit_position : Vector3) -> void:
	var other_velocity := Vector3.ZERO;
	var other_rigidbody := body as RigidBody3D;
	if other_rigidbody:
		other_velocity = self.linear_velocity;
	var velocity_delta := self.linear_velocity - other_velocity;
	var velocity_delta_size := velocity_delta.length();
	var impulse_size := impulse.length();
	
	if impulse_size > 0.3:
		#print("%s hit with %f at %f <%s>" % [body.name, impulse_size, velocity_delta_size, velocity_delta]);
		pass 
		
	if impulse_size > 3.5:
		#print("Plonk");
		if impact_sfx != null:
			var sfx_node := AudioStreamPlayer3D.new();
			get_parent().add_child(sfx_node) # probably bad
			sfx_node.stream = impact_sfx;
			sfx_node.pitch_scale = randf_range(0.6, 0.8) * (1.0 + log(1.0 + impulse_size - 3.5) * 1.3);
			sfx_node.volume_db = (impulse_size - 3.5) * 20.0 - 30.0;
			sfx_node.max_db = 10.0;
			sfx_node.global_position = hit_position;
			sfx_node.play();
		
	pass

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var contacts := state.get_contact_count();
	for i in contacts:
		if state.get_contact_impulse(i).length_squared() > 0:
			contact_entered.emit(
				state.get_contact_collider_object(i) as Node,
				state.get_contact_local_normal(i),
				state.get_contact_impulse(i),
				state.get_contact_collider_position(i)
				);
	
	pass
