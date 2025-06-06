shader_type canvas_item;

uniform float circle_size : hint_range(0.0, 2.0) = 0.0;
uniform vec2 circle_center = vec2(0.5, 0.5);
uniform bool invert_mask = false;

void fragment() {
    // Calculate distance from center (normalized for aspect ratio)
    vec2 uv = UV;
    float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
    vec2 center = circle_center;
    
    // Adjust for aspect ratio
    uv.y *= aspect;
    center.y *= aspect;
    
    // Calculate distance
    float dist = distance(uv, center);
    
    // Inside circle is visible (1), outside is hidden (0)
    float mask = 1.0 - step(circle_size, dist);
    
    // Apply inversion if needed
    if (invert_mask) {
        mask = 1.0 - mask;
    }
    
    // Apply the mask
    COLOR.a = mask;
}