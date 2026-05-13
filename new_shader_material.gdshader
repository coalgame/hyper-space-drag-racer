shader_type spatial;

uniform vec2 curve_strength = vec2(0.001, 0.001); // x = horizontal, y = vertical
uniform float distance_offset = 0.0;

void vertex() {
	// 1. Get vertex in Model View space
	vec4 view_vert = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	
	// 2. Calculate depth
	float z_dist = abs(view_vert.z) - distance_offset;
	
	if (z_dist > 0.0) {
		// 3. Calculate offsets for both axes
		// Using z_dist^2 for that smooth exponential curve
		float x_offset = curve_strength.x * pow(z_dist, 2.0);
		float y_offset = curve_strength.y * pow(z_dist, 2.0);
		
		// 4. Apply to world space
		vec4 world_vert = MODEL_MATRIX * vec4(VERTEX, 1.0);
		world_vert.x += x_offset;
		world_vert.y += y_offset;
		
		// 5. Back to local space
		VERTEX = (inverse(MODEL_MATRIX) * world_vert).xyz;
	}
}

void fragment(){
	{
		// Distance Fade: Object Dither
		float fade_distance = length((VIEW_MATRIX * MODEL_MATRIX[3]));

		// Use interleaved gradient noise, which is fast but still looks good.
		const vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
		float fade = clamp(smoothstep(2, 6, fade_distance), 0.0, 1.0);
		// Use a hard cap to prevent a few stray pixels from remaining when past the fade-out distance.
		if (fade < 0.001 || fade < fract(magic.z * fract(dot(FRAGCOORD.xy, magic.xy)))) {
			discard;
		}
	}
}