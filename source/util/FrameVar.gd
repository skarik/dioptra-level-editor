class_name FrameVar

class AsVariant:
	extends RefCounted # TODO: is there a way to have a value-type instead?
	var value : Variant;
	var previous : Variant;

	func process(newValue : Variant) -> void:
		previous = value;
		value = newValue;
		
	func was_changed() -> bool:
		return value != previous;

class AsBool:
	extends RefCounted # TODO: is there a way to have a value-type instead?
	var value : bool;
	var previous : bool;
	var wasProcessed : bool = false;
	
	func _init(startValue : bool) -> void:
		value = startValue;
	
	# Combined processing
	func process(newValue : bool) -> void:
		previous = value;
		value = newValue;
		wasProcessed = true;

	# Separated processing
	func updateValue(newValue : bool) -> void:
		if (wasProcessed):
			previous = value;
		value = newValue;
		wasProcessed = false;
		
	func updateProcess() -> void:
		if (wasProcessed):
			previous = value;
		wasProcessed = true;

	func was_changed() -> bool:
		return value != previous;
	
	func was_enabled() -> bool:
		return was_changed() && value == true;
	
	func was_disabled() -> bool:
		return was_changed() && value == false;
		
	func is_enabled() -> bool:
		return value;
		
