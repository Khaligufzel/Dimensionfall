shader_type spatial;

uniform sampler2D tex;
uniform vec4 color: source_color = vec4(0, 1, 1, 1);
uniform float energy: hint_range(0, 16) = 1;

void fragment() {
	EMISSION = color.rgb * energy;
	ALPHA = 0.0;
}

void light() {
	vec4 pixel = textureLod(tex, UV, 0);
	DIFFUSE_LIGHT = vec3(0.0);
	ALPHA = length(ATTENUATION) * pixel.a;
}
