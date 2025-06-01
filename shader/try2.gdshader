shader_type canvas_item;

uniform int hframes = 4;
uniform int vframes = 1;
uniform float anim_speed = 10.0;

void fragment() {
    int total_frames = hframes * vframes;

    float anim_time = TIME * anim_speed;
    int frame = int(mod(anim_time, float(total_frames)));

    int frame_x = frame % hframes;
    int frame_y = 0;

    vec2 frame_size = vec2(1.0) / vec2(float(hframes), float(vframes));
    vec2 frame_offset = vec2(float(frame_x), float(frame_y)) * frame_size;

    vec2 atlas_uv = frame_offset + UV * frame_size;

    COLOR = texture(TEXTURE, atlas_uv);
}
