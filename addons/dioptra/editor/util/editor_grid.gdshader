shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, world_vertex_coords;

uniform bool enabled;
uniform float grid_size;
uniform vec3 cursor_position;
uniform float cursor_radius;

varying vec4 v_world_position;
varying vec3 v_world_normal;

void vertex() {
	vec3 eye_delta = CAMERA_POSITION_WORLD - VERTEX;
	float eye_distance = (dot(eye_delta, eye_delta));
	v_world_position = vec4(VERTEX, eye_distance);
	v_world_normal = NORMAL;
}

void fragment() {
	if (!enabled)
		discard;
	
	float eye_distance = v_world_position.w;
	float pixel_scale = 0.5f * log(eye_distance * 2.0f + 1.0f); // going for aesthetics & usability, not correctness
	
	// Generate a UV grid:
	float grid_halfsize = grid_size * 0.5f;
	const float GRID_WIDTH = 1.3f;
	const float GRID_SHARPNESS = 70.0f;
	const float MAJORGRID_MUL = 8.0f;
	
	vec3 _dummy;

	vec3 normal_blend = clamp(abs(v_world_normal) * 3.0 - 2.0, vec3(0.0), vec3(1.0));

	vec3 world_grid = abs(modf(v_world_position.xyz / vec3(grid_halfsize * 2.0f) + 0.5, _dummy));
	vec3 world_grid_bias = mix(abs(world_grid - 0.5), vec3(1.0), normal_blend);
	float world_grid_mindist = min(min(world_grid_bias.x, world_grid_bias.y), world_grid_bias.z);
	float world_gridline = clamp((GRID_WIDTH * pixel_scale - world_grid_mindist * GRID_SHARPNESS), 0.0, 1.0);
	
	vec3 world_majorgrid = abs(modf(v_world_position.xyz / vec3(grid_halfsize * 2.0f * MAJORGRID_MUL) + 0.5, _dummy));
	vec3 world_majorgrid_bias = mix(abs(world_majorgrid - 0.5), vec3(1.0), normal_blend);
	float world_majorgrid_mindist = min(min(world_majorgrid_bias.x, world_majorgrid_bias.y), world_majorgrid_bias.z);
	float world_majorgridline = clamp((GRID_WIDTH * pixel_scale * 0.5 - world_majorgrid_mindist * GRID_SHARPNESS), 0.0, 1.0);
	
	float cursor_distance = length(v_world_position.xyz - cursor_position);
	float cursor_brighten = clamp(1.0 - cursor_distance / cursor_radius, 0.0, 1.0);
	
	ALPHA = clamp((world_gridline * 0.125 + world_majorgridline * 0.25) * (0.2 + cursor_brighten * 0.8), 0.0, 1.0);
	ALBEDO = vec3(1, 1, 1);
	EMISSION = vec3(0.3, 0.3, 0.3) * (1.0 + cursor_brighten * 0.5);
	RADIANCE = vec4(0.0);
	IRRADIANCE = vec4(0.0);
	//ALPHA_SCISSOR_THRESHOLD = 0.01;
}

