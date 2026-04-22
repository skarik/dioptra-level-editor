extends Resource
class_name GMCharacterMotionSettings

# Motion Settings
#------------------------------------------------------------------------------#

# Ground settings
@export var max_ground_walk_speed : float = 4.0; ## Max walking speed on ground
@export var max_ground_sprint_speed : float = 7.5; ## Max sprinting speed on ground
@export var ground_acceleration : float = 15.0; ## Positive acceleration
@export var ground_friction : float = 50.0; ## Negative acceleration when inputs let go
@export var backwards_max_speed_percent : float = 0.8; ## Percent of the max move speed we can go backwards

# Air settings
@export var jump_velocity : float = 5.0; ## Upwards velocity applied when jumping
@export var grind_speed = 11.0; ## Speed when grinding rails

# Dash options
@export var dash_time : float = 0.14; ## Length of a dash
@export var dash_speed : float = 20.0; ## Speed of a dash
