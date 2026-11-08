
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 30.0) = 2.0;

void fragment() {
	vec4 original = texture(TEXTURE, UV);

	vec2 offset = TEXTURE_PIXEL_SIZE * outline_width;

	float alpha = 0.0;

	alpha = max(alpha, texture(TEXTURE, UV + vec2(offset.x, 0.0)).a);
	alpha = max(alpha, texture(TEXTURE, UV - vec2(offset.x, 0.0)).a);
	alpha = max(alpha, texture(TEXTURE, UV + vec2(0.0, offset.y)).a);
	alpha = max(alpha, texture(TEXTURE, UV - vec2(0.0, offset.y)).a);

	alpha = max(alpha, texture(TEXTURE, UV + vec2(offset.x, offset.y)).a);
	alpha = max(alpha, texture(TEXTURE, UV + vec2(-offset.x, offset.y)).a);
	alpha = max(alpha, texture(TEXTURE, UV + vec2(offset.x, -offset.y)).a);
	alpha = max(alpha, texture(TEXTURE, UV - offset).a);

	if (original.a < 0.01 && alpha > 0.01) {
		COLOR = outline_color;
	} else {
		COLOR = original;
	}
}
