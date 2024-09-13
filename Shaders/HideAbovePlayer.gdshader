shader_type spatial;

uniform sampler2D texture_albedo;
global uniform float player_y_level;

void fragment() {
	// Compute the world position using the built-in INV_VIEW_MATRIX
	vec4 world_pos = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);

	// Discard the fragment if it's above the player y-level
	if (world_pos.y - 0.5 > player_y_level) {
		discard;
	} else {
		ALBEDO = texture(texture_albedo, UV).rgb;
		ALPHA = texture(texture_albedo, UV).a;
	}
}