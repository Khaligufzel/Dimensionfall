shader_type spatial;

// Uniforms for texture, color, and alpha transparency
uniform sampler2D texture_albedo;
uniform vec4 object_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);  // Default color is white with full alpha
uniform float alpha : hint_range(0.0, 1.0) = 1.0;  // Default alpha is 1.0 (fully opaque)
uniform float y_offset = 0.0;

global uniform float player_y_level;

void fragment() {
    // Compute the world position using INV_VIEW_MATRIX (camera space to world space)
    vec4 world_pos = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);

    // Discard the fragment if it's above the player y-level
    if (world_pos.y - y_offset > player_y_level) {
        discard;
    } else {
        // Sample the texture color
        vec3 albedo_color = texture(texture_albedo, UV).rgb;

        // Apply the object color and transparency
        ALBEDO = albedo_color * object_color.rgb;  // Multiply texture with object color
        ALPHA = texture(texture_albedo, UV).a * alpha;  // Apply transparency
    }
}