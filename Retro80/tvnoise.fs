#version 120

varying vec2 texcoord;

uniform vec2 resolution;
uniform float time;

uniform sampler2D tex0;
uniform sampler2D tex1;

uniform bool grayscale;
uniform bool blend;

float distortion = 0.1;
float zoom = 1.0;

float rand(vec2 co) {
	return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void main() {

	// radial distortion

	vec2 uv = texcoord - 0.5;
	float dist = dot(uv, uv) * distortion;
	uv = 0.5 + (texcoord.xy + uv * (1.0 + dist) * dist - 0.5) * zoom;

	// subtle zoom in/out

	uv = 0.5 + (uv - 0.5) * (0.997 + 0.003 * sin(0.95 * time));

//	if (uv.s < 0.0 || uv.s > 1.0 || uv.t < 0.0 || uv.t > 1.0) {
//		gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0); return;
//	}

	if (uv.s < 0.0) uv.s = 0.0;
	if (uv.s > 1.0) uv.s = 1.0;
	if (uv.t < 0.0) uv.t = 0.0;
	if (uv.t > 1.0) uv.t = 1.0;

	// original color

	vec4 color = texture2D(tex0, uv); if (blend) {
		vec4 c = texture2D(tex1, uv);
		color = mix(color, c, c.a);
	}

	// rgb shift

	vec4 col;
	col.r = texture2D(tex0,vec2(uv.x+1.0/resolution.x,uv.y)).x;
	col.g = texture2D(tex0,vec2(uv.x,uv.y)).y;
	col.b = texture2D(tex0,vec2(uv.x-1.0/resolution.x,uv.y)).z;
	col.a = texture2D(tex0,uv).a;

	if (blend)
	{
		vec4 c;
		c.r = texture2D(tex1,vec2(uv.x+1.0/resolution.x,uv.y)).x;
		c.g = texture2D(tex1,vec2(uv.x,uv.y)).y;
		c.b = texture2D(tex1,vec2(uv.x-1.0/resolution.x,uv.y)).z;
		c.a = texture2D(tex1,uv).a;
		col = mix(col, c, c.a);
	}

	// contrast curve

//	col.xyz = clamp(col.xyz * 0.5 + 0.5 * col.xyz * col.xyz * 1.2, 0.0, 1.0);

	// vignette

//	col.xyz *= 0.6 + 0.4 * 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);

	// color tint

//	col.xyz *= vec3(0.93, 1.0, 0.8);

	// scanline (last 2 constants are crawl speed and size)

	col *= 0.8 + 0.2 * sin(10.0 * time + texcoord.y * resolution.y * 8.0);

	// flickering (semi-randomized)

//	col.xyz *= 1.0 - 0.07 * rand(vec2(time, tan(time)));

	if (grayscale)
	{
		gl_FragColor.r = gl_FragColor.g = gl_FragColor.b = dot(col.rgb, vec3(0.3, 0.59, 0.11));
	}
	else
	{
		gl_FragColor = col;
	}
}
