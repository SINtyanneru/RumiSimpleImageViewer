#version 330 core

layout(location = 0) in vec2 pos;
layout(location = 1) in vec2 uv;

uniform vec2 u_win;
uniform vec2 u_img;
uniform vec2 u_off;
uniform float u_zoom;

out vec2 v_uv;

void main() {
	v_uv = uv;

	vec2 px = pos * 0.5 * u_img * u_zoom + u_off;

	gl_Position = vec4(
		px / (u_win * 0.5),
		0.0,
		1.0
	);
}