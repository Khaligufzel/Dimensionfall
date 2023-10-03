shader_type canvas_item;
void fragment() {
if(AT_LIGHT_PASS) {
// For all fragments in the light
COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0);
}
else {
// For all other fragments
COLOR = vec4(texture(TEXTURE, UV).rgb, 0.0);
}
}