shader_type canvas_item;
// Screen-space mood: vignette, wobble/chroma "distortion", grade. Driven by Narrative profiles.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float vignette = 0.0;
uniform float distort = 0.0;
uniform float sat = 1.0;
uniform float contrast = 1.0;
uniform vec3 tint = vec3(1.0);
uniform float grain = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = vec2(sin(uv.y * 18.0 + TIME * 1.7), cos(uv.x * 14.0 + TIME * 1.3)) * 0.0035 * distort;
	uv += d;
	float ca = 0.004 * distort;
	vec3 c;
	c.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sat);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint;
	float r = length(SCREEN_UV - 0.5) * 1.35;
	c *= 1.0 - vignette * smoothstep(0.25, 1.0, r);
	c += (hash(SCREEN_UV * 900.0 + TIME) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
