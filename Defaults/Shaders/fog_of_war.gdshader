shader_type spatial;

uniform sampler2D fog_texture; // The texture storing fog information
uniform vec2 fog_texture_size; // Size of the fog texture
uniform vec3 fog_color = vec3(0.0, 0.0, 0.0); // Color of the fog

void fragment() {
    // Get the world position of the fragment
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Convert the world position to the fog texture UV coordinates
    vec2 uv = (world_pos.xz / fog_texture_size) + 0.5;

    // Sample the fog texture
    float fog_factor = texture(fog_texture, uv).r;

    // Interpolate between the original color and the fog color
    vec3 color = mix(fog_color, vec3(1.0), fog_factor);

    // Set the final fragment color
    ALBEDO = color;
}
