shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D mainTexture : source_color;
uniform uint sheetRows;
uniform uint sheetColumns;
uniform uint sheetFrames;
uniform float textureRotation;

void vertex() {
	float rotationInRadians = textureRotation * PI / 180.0f;
	float sin_factor = sin(rotationInRadians);
    float cos_factor = cos(rotationInRadians);
	mat2 texture_rotation = mat2(vec2(cos_factor, sin_factor), vec2(-sin_factor, cos_factor));

	vec2 sheetStep = vec2(1.0, 1.0) / vec2(uvec2(sheetColumns, sheetRows));
	uint frame = uint(float(sheetFrames) * INSTANCE_CUSTOM.z);

	vec2 calulatedUVs = ((UV - 0.5) * texture_rotation) + 0.5;
	calulatedUVs *= sheetStep;
	calulatedUVs.x += float(frame % sheetColumns) * sheetStep.x;
	calulatedUVs.y += float(frame / sheetColumns) * sheetStep.y;



	UV = calulatedUVs;
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 textureColor = texture(mainTexture, UV);
	ALBEDO = textureColor.rgb;
	ALPHA = textureColor.a;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
