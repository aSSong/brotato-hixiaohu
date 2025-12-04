shader_type canvas_item;

uniform float radius = 0.5;
uniform vec4 color : source_color;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    if (dist > radius) {
        discard;
    }
    COLOR = color;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
