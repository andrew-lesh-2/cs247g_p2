shader_type particles;

uniform int hframes = 4;       // number of horizontal frames
uniform int vframes = 4;       // number of vertical frames
uniform float anim_speed = 10.0;

varying vec2 atlas_uv;

void vertex() {
    int total_frames = hframes * vframes;

    // Use TIME and RANDOM_SEED to get a per-particle animation phase
    float anim_time = TIME * anim_speed * float(total_frames);
    int frame = int(mod(anim_time, float(total_frames)));

    // Calculate grid coordinates for this frame
    int frame_x = frame % hframes;
    int frame_y = frame / hframes;

    // Get size of one frame
	vec2 frame_size = vec2(1.0, 1.0) / vec2(float(hframes), float(vframes));

    // Offset to the correct tile
    vec2 frame_offset = vec2(float(frame_x), float(frame_y)) * frame_size;

    // Scale and shift the UV so it shows only that tile
    atlas_uv = frame_offset + POINT_COORD * frame_size;

    // Normal transform
    TRANSFORM = Transform2D(ANGLE, VELOCITY);
}
