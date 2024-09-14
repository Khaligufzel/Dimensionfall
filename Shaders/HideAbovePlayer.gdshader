shader_type spatial;

// This shader hides objects above the player that have a ShaderMaterial and apply this shader
// This is applied to furniture for example. This shader is instanced in Gamedata.gd

// Uniforms for texture, color, alpha transparency, and y-offset
uniform sampler2D texture_albedo;
uniform vec4 object_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);  // Default color is white with full alpha
uniform float alpha : hint_range(0.0, 1.0) = 1.0;  // Default alpha is 1.0 (fully opaque)

global uniform float player_y_level;

void fragment() {
    // Compute the world position using INV_VIEW_MATRIX (camera space to world space)
    vec4 world_pos = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);

    // Clamp the world y position to a whole number to unify the fragment evaluation
    float clamped_y = floor(world_pos.y + 0.5);  // Clamping to the nearest integer

    // If the clamped world position is above the player y-level, discard the fragment
	// If you change the 0.2, you will see that as the player climbs the stairs, furniture
	// sprites and mesh becomes visible earlier of later, depending on whether you raise it or lower it
    if (clamped_y - 0.2 > player_y_level) {
        discard;  // Hide all fragments for this mesh
    } else {
        // Sample the texture color
        vec3 albedo_color = texture(texture_albedo, UV).rgb;

        // Apply the object color and transparency
        ALBEDO = albedo_color * object_color.rgb;  // Multiply texture with object color
        ALPHA = texture(texture_albedo, UV).a * alpha;  // Apply transparency
    }
}
