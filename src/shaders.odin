package main

// Rectangle vertex shader

RECT_VERTEX_SHADER :: `
attribute vec2 position;

uniform vec2 resolution;
uniform vec2 rect_position;

varying vec2 local_position;

void main() {
    local_position = position - rect_position;

    vec2 zero_to_one = position / resolution;
    vec2 zero_to_two = zero_to_one * 2.0;
    vec2 clip_space = zero_to_two - 1.0;

    clip_space.y = -clip_space.y;

    gl_Position = vec4(clip_space, 0.0, 1.0);
}
`


// Rectangle fragment shader

RECT_FRAGMENT_SHADER :: `
precision mediump float;

uniform vec4 color;

uniform vec2 rect_size;
uniform float rect_radius;

varying vec2 local_position;

void main() {
    vec2 half_size = rect_size * 0.5;

    vec2 p = local_position - half_size;

    vec2 q =
        abs(p) -
        half_size +
        vec2(rect_radius);

    float distance =
        length(max(q, 0.0)) +
        min(max(q.x, q.y), 0.0) -
        rect_radius;

    float alpha =
        1.0 - smoothstep(0.0, 1.0, distance);

    gl_FragColor = vec4(
        color.rgb,
        color.a * alpha
    );
}
`


// Text vertex shader

TEXT_VERTEX_SHADER :: `
attribute vec2 position;
attribute vec2 tex_coord;

uniform vec2 resolution;

varying vec2 v_tex_coord;

void main() {
    vec2 zero_to_one = position / resolution;
    vec2 zero_to_two = zero_to_one * 2.0;
    vec2 clip_space = zero_to_two - 1.0;

    clip_space.y = -clip_space.y;

    gl_Position = vec4(clip_space, 0.0, 1.0);

    v_tex_coord = tex_coord;
}
`


// Text fragment shader

TEXT_FRAGMENT_SHADER :: `
precision mediump float;

uniform sampler2D glyph_texture;
uniform vec4 text_color;

varying vec2 v_tex_coord;

void main() {
    float coverage = texture2D(
        glyph_texture,
        v_tex_coord
    ).a;

    gl_FragColor = vec4(
        text_color.rgb,
        text_color.a * coverage
    );
}
`
