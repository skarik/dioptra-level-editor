shader_type spatial;
render_mode unshaded, cull_disabled;

void vertex() {
	// Called for every vertex the material is visible on.
	VERTEX = VERTEX;
	COLOR = COLOR;
}

void fragment() {
	// Called for every pixel the material is visible on.
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
