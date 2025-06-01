shader_type canvas_item;

uniform vec4 color1 : source_color;
uniform vec4 color2 : source_color;
uniform bool vertical = true;

void fragment() {
    float t = vertical ? UV.y : UV.x;
    COLOR = mix(color1, color2, t);
}
