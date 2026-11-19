#version 330 core

in vec2 v_uv;

uniform sampler2D tex;
uniform vec4 u_color;

out vec4 color;

void main() {
	color = texture(tex, v_uv) * u_color;
}
