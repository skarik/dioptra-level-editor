shader_type spatial;
render_mode skip_vertex_transform, unshaded, cull_disabled;

const float AA_RADIUS = 0.707;

void vertex() {
	// Start with default position
	vec4 v_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	// We work in clip space because I'm tired of not knowing where the W is.
	// So to get the big W we work in clip space.

	vec2 pixel_size = vec2(1.0, 1.0) / VIEWPORT_SIZE;
	float aspect_ratio = float(VIEWPORT_SIZE.x) / VIEWPORT_SIZE.y;
	// Transform the normal into screen space & use that to get the local left param
	vec4 screen_normal = PROJECTION_MATRIX * vec4((MODELVIEW_NORMAL_MATRIX * NORMAL), 0.0);
	screen_normal.y /= aspect_ratio;
	vec2 screen_side = vec2(-screen_normal.y, screen_normal.x); // Rotate normally
	float screen_side_xy_len = length(screen_side.xy);

	// Make the line the correct width & adjust for depth
	vec2 offset = screen_side.xy / screen_side_xy_len * pixel_size;
	offset *= mix(-1.0, 1.0, UV.x);
	offset *= v_position.w;
	offset *= UV2.x + AA_RADIUS;

	// Apply outline offset
	v_position.xy += offset;

	// Get final position
	POSITION = v_position;

	// Pass other junk to pixel shader
	COLOR = COLOR;
	UV = vec2(UV.x, AA_RADIUS / (UV2.x + AA_RADIUS));
}

void fragment() {
	// Use UV to get the fade out gradient
	float in_width_grad = UV.x;
	float in_aa_width_ratio = UV.y;
	float alpha_blend =
		min(1.0, in_width_grad / in_aa_width_ratio)
		* min(1.0, (1.0 - in_width_grad) / in_aa_width_ratio);

	// Apply!
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * alpha_blend;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
