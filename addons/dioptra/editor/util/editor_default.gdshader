shader_type spatial;
render_mode unshaded, world_vertex_coords;

varying vec3 v_world_normal;

void vertex() {
	VERTEX = VERTEX;
	COLOR = COLOR;
	UV = UV;
	UV2 = UV2;
	NORMAL = NORMAL;
	v_world_normal = NORMAL;
}

void fragment() {
	// Get a default lighting value
	float normal_atten = dot(v_world_normal, vec3(0.8, 1.0, 0.5));

	// Generate a UV grid:
	const float GRID_HALFSIZE = 0.125f;
	const float GRID_WIDTH = 1.3f;
	const float GRID_SHARPNESS = 70.0f;
	const float SUBGRID_HALFSIZE = 0.25f * 0.25f * 0.5f;

	vec2 _dummy;

	vec2 uv_grid = abs(modf(UV / vec2(GRID_HALFSIZE * 2.0f) + 0.5, _dummy));
	float min_dist = min(abs(uv_grid.x - 0.5), abs(uv_grid.y - 0.5));
	float uv_gridline = clamp(GRID_WIDTH - min_dist * GRID_SHARPNESS, 0.0, 1.0);

	vec2 uv_subgrid = abs(modf(UV / vec2(SUBGRID_HALFSIZE * 2.0f) + 0.5, _dummy));
	float min_subdist = min(abs(uv_subgrid.x - 0.5), abs(uv_subgrid.y - 0.5));
	float uv_subgridline = clamp(GRID_WIDTH - min_subdist * GRID_SHARPNESS, 0.0, 1.0);

	// Make a color
	vec3 color = mix(vec3(0.5, 0.5, 0.5), vec3(1, 1, 1), min(1.0, uv_gridline + uv_subgridline * 0.5));

	// Set up alpha at the end
	ALBEDO = COLOR.rgb * color * abs(normal_atten);
}
