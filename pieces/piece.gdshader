shader_type spatial;

render_mode unshaded;

#include "res://world/world_bend.gdshaderinc"

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;

void vertex() {
	UV = UV;

	apply_world_bend(VERTEX, MODEL_MATRIX, MODELVIEW_MATRIX);
}

void fragment(){
	
	vec2 base_uv = UV;

	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;

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