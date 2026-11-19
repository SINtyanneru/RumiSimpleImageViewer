#version 330 core

layout(location = 0) in vec2 pos;
layout(location = 1) in vec2 uv;

uniform vec2 u_win;
uniform vec2 u_pos;
uniform vec2 u_size;

out vec2 v_uv;

void main() {
	v_uv = vec2(uv.x, 1.0 - uv.y);

	vec2 px = (pos * 0.5 + 0.5) * u_size + u_pos;

	gl_Position = vec4(
		px.x / u_win.x * 2.0 - 1.0,
		1.0 - px.y / u_win.y * 2.0,
		0.0,
		1.0
	);
}
