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
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform vec4 color;
uniform vec4 border_color;

uniform vec2 rect_size;
uniform float rect_radius;
uniform float border_size;

varying vec2 local_position;

float rounded_rect_distance(
    vec2 p,
    vec2 half_size,
    float radius
) {
    vec2 q =
        abs(p) -
        half_size +
        vec2(radius);

    return
        length(max(q, 0.0)) +
        min(max(q.x, q.y), 0.0) -
        radius;
}

float coverage(float distance) {
    // One-pixel AA band centred exactly on the edge.
    return 1.0 - smoothstep(
        -0.5,
         0.5,
         distance
    );
}

void main() {
    vec2 half_size = rect_size * 0.5;
    vec2 p = local_position - half_size;

    // Outer shape

    float outer_distance = rounded_rect_distance(
        p,
        half_size,
        rect_radius
    );

    float outer_alpha = coverage(
        outer_distance
    );

    // Inner shape / border

    float inset = max(
        border_size,
        0.0
    );

    vec2 inner_half_size = max(
        half_size - vec2(inset),
        vec2(0.0)
    );

    float inner_radius = max(
        rect_radius - inset,
        0.0
    );

    float inner_distance = rounded_rect_distance(
        p,
        inner_half_size,
        inner_radius
    );

    float inner_alpha = coverage(
        inner_distance
    );

    vec4 result = mix(
        border_color,
        color,
        inner_alpha
    );

    float alpha =
        result.a *
        outer_alpha;

    // Premultiplied alpha.
    gl_FragColor = vec4(
        result.rgb * alpha,
        alpha
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
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform sampler2D glyph_texture;
uniform vec4 text_color;

varying vec2 v_tex_coord;

void main() {
    float coverage = texture2D(
        glyph_texture,
        v_tex_coord
    ).a;

    float alpha =
        text_color.a *
        coverage;

    gl_FragColor = vec4(
        text_color.rgb * alpha,
        alpha
    );
}
`
