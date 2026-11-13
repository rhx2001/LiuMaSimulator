shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

// 每片碎片是一个小方片；亮度 = 基础 + 高光 + 每片随机相位的闪烁。
uniform float base_brightness : hint_range(0.0, 1.0) = 0.04;
uniform vec3 light_dir = vec3(0.35, 0.85, 0.4);
uniform float shininess : hint_range(8.0, 2048.0) = 400.0;
uniform float twinkle_speed = 3.0;

varying float phase;

void vertex() {
	phase = COLOR.r; // 实例颜色只用 r 通道存随机相位
}

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 l = normalize(light_dir);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	vec3 h = normalize(l + v);
	float spec = pow(max(dot(n, h), 0.0), shininess);
	float tw = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TIME * twinkle_speed + phase * 6.2831853), 3.0);
	ALBEDO = vec3(1.0) * (base_brightness + spec * 2.5) * tw;
}
