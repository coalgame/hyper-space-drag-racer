// world_bend.gdshaderinc

// We use global uniforms so you can control every material at once
global uniform vec2 world_curve;
global uniform float world_curve_z_dist;

// This function handles the math
void apply_world_bend(inout vec3 vertex, mat4 model_matrix, mat4 modelview_matrix) {
    // 1. Get depth relative to camera
    vec4 view_vert = modelview_matrix * vec4(vertex, 1.0);
    float z_dist = abs(view_vert.z) - world_curve_z_dist;
    
    if (z_dist > 0.0) {
        // 2. Calculate the squared offset
        float x_offset = world_curve.x * pow(z_dist, 2.0);
        float y_offset = world_curve.y * pow(z_dist, 2.0);
        
        // 3. Move the vertex in world space
        vec4 world_vert = model_matrix * vec4(vertex, 1.0);
        world_vert.x += x_offset;
        world_vert.y += y_offset;
        
        // 4. Update the vertex by converting back to local space
        vertex = (inverse(model_matrix) * world_vert).xyz;
    }
}