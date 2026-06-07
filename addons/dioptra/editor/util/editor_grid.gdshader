shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, world_vertex_coords;

uniform bool enabled;
uniform float grid_size;
uniform vec3 cursor_position;
uniform float cursor_radius;

uniform bool enable_grid;
uniform bool enable_wires;

varying vec4 v_world_position;
varying vec3 v_world_normal;
varying vec4 v_barycentric;

void vertex() {
	vec3 eye_delta = CAMERA_POSITION_WORLD - VERTEX;
	float eye_distance = (dot(eye_delta, eye_delta));
	v_world_position = vec4(VERTEX, eye_distance);
	v_world_normal = NORMAL;
	
	v_barycentric = COLOR;
}

void get_grid(out float o_alpha, out vec3 o_emission, out vec3 o_diffuse)
{
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
	
	o_alpha = clamp((world_gridline * 0.125 + world_majorgridline * 0.25) * (0.2 + cursor_brighten * 0.8), 0.0, 1.0);
	o_emission = vec3(0.3, 0.3, 0.3) * (1.0 + cursor_brighten * 0.5);
	o_diffuse = vec3(1.0, 1.0, 1.0);
}

void get_wire(out float o_alpha, out vec3 o_emission, out vec3 o_diffuse)
{
	// Lines have to be from X to Y, or Y to Z, or Z to W, or W to X.
	vec4 line_detect = vec4(
		v_barycentric.x + v_barycentric.y,
		v_barycentric.y + v_barycentric.z,
		v_barycentric.z + v_barycentric.w,
		v_barycentric.w + v_barycentric.x);
	
	vec4 deriv = fwidth(line_detect);
	vec4 remap = step(deriv * 1.0, line_detect);
	float closest_edge = min(remap.x, min(remap.y, min(remap.z, remap.w)));
	
	const vec3 LINE_COLOR = vec3(0.2, 0.65, 1.0);
	
	o_alpha = clamp(1.0 - closest_edge, 0.0, 1.0);
	o_emission = LINE_COLOR;
	o_diffuse = LINE_COLOR;
}

void fragment() {
	if (!enabled)
		discard;
	if (!enable_grid && !enable_wires)
		discard;
	
	float alpha = 0.0;
	vec3 emission = vec3(0.0);
	vec3 diffuse = vec3(1.0);
	
	if (enable_grid)
	{
		float grid_alpha = 0.0;
		vec3 grid_emission = vec3(0.0);
		vec3 grid_diffuse = vec3(1.0);
		get_grid(grid_alpha, grid_emission, grid_diffuse);
		
		alpha = grid_alpha;
		emission = grid_emission;
		diffuse = grid_diffuse;
	}
	
	if (enable_wires)
	{
		float wire_alpha = 0.0;
		vec3 wire_emission = vec3(0.0);
		vec3 wire_diffuse = vec3(0.0);
		get_wire(wire_alpha, wire_emission, wire_diffuse);
		
		alpha = max(wire_alpha * 0.717, alpha);
		emission = mix(emission, wire_emission, wire_alpha);
		diffuse = mix(diffuse, wire_diffuse, wire_alpha);
	}
	
	if (alpha <= 0.0)
		discard;
	
	ALPHA = alpha;
	ALBEDO = diffuse;
	EMISSION = emission;
	RADIANCE = vec4(0.0);
	IRRADIANCE = vec4(0.0);
	//ALPHA_SCISSOR_THRESHOLD = 0.001;
}

