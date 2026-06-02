shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://world/world_bend.gdshaderinc"

uniform vec4 albedo : source_color;

void vertex() {
    apply_world_bend(VERTEX, MODEL_MATRIX, MODELVIEW_MATRIX);
}

void fragment() {
    ALBEDO = albedo.rgb;
    METALLIC = 0.0;
    SPECULAR = 0.5;
    ROUGHNESS = 1.0;
}
