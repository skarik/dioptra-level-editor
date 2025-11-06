shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D mainTexture : source_color;
uniform sampler2D glassColorsTexture : source_color;
uniform sampler2D glassShineTexture : source_color, hint_default_black;
uniform uint sheetRows;
uniform uint sheetColumns;
uniform uint sheetFrames;
uniform float textureRotation;

varying vec2 UV3;

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

	vec2 glassUVs = vec2(float(INSTANCE_ID % 8), float(INSTANCE_ID / 8));
	glassUVs += vec2(0.5, 0.5);
	glassUVs /= vec2(8.0, 3.0);

	vec3 viewPosition = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 viewNormal = MODELVIEW_NORMAL_MATRIX * NORMAL;
	vec2 shineUVs = viewPosition.xy + viewNormal.xy;
	mat2 shineRotation = mat2(vec2(viewNormal.x, -viewNormal.y), viewNormal.yx);

	shineUVs = shineUVs.xy * shineRotation;
	shineUVs *= 3.0;

	UV = calulatedUVs;
	UV2 = glassUVs;
	UV3 = shineUVs;
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 textureColor = texture(mainTexture, UV);
	vec4 glassColor = texture(glassColorsTexture, UV2);
	vec4 glassShine = texture(glassShineTexture, UV3);
	vec3 glassColorShined = glassColor.rgb * (1.0 + glassShine.rgb * 4.0);
	ALBEDO = min(vec3(1.0, 1.0, 1.0), textureColor.rgb + glassColorShined);
	ALPHA = textureColor.a * COLOR.a;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
