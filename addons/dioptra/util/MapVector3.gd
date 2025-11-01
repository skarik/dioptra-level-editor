extends RefCounted # TODO: is there a way to have a value-type instead? If not, move this class to C++
class_name MapVector3
## A vector class that holds an integer vector with precision related to the current map DP interface.
## 

var _value : Vector3i;

## Converts the MapVector to and from a global position vector.
var v3 : Vector3:
	get = get_v3,
	set = set_v3

func _init(v : Vector3 = Vector3.ZERO) -> void:
	set_v3(v);
	
func _to_string() -> String:
	return "<%d, %d, %d>" % [_value.x, _value.y, _value.z];
	
## Sets the value of map vector and truncates the value
func set_v3(v : Vector3) -> void:
	_value = Vector3i((v / DioptraInterface.get_position_scale_div()) * DioptraInterface.get_position_scale_top());
## Returns the current value of the map vector in normal godot space
func get_v3() -> Vector3:
	return Vector3(_value * DioptraInterface.get_position_scale_div()) / DioptraInterface.get_position_scale_top();

## Adds
func add(v : MapVector3) -> MapVector3:
	_value += v._value;
	return self;
## Subtracts
func sub(v : MapVector3) -> MapVector3:
	_value -= v._value;
	return self;
## Multiplies
func mul(value : int) -> MapVector3:
	_value *= value;
	return self;
## Equals?
func equals(v : MapVector3) -> bool:
	return _value == v._value;
