extends Control

var warp_amount: float = 0.0
var phase: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
    phase += delta
    queue_redraw()

func _draw() -> void:
    var s: Vector2 = size
    var center: Vector2 = Vector2(s.x * 0.50, s.y * 0.47)
    var cyan := Color(0.19, 0.93, 0.98, 0.67)
    var muted := Color(0.08, 0.65, 0.89, 0.21)
    draw_arc(center, 31.0, 0.29, 1.41, 18, cyan, 1.7, true)
    draw_arc(center, 31.0, 1.87, 2.97, 18, cyan, 1.7, true)
    draw_arc(center, 31.0, 3.42, 4.59, 18, cyan, 1.7, true)
    draw_arc(center, 31.0, 5.04, 6.08, 18, cyan, 1.7, true)
    draw_line(center + Vector2(-13, 0), center + Vector2(13, 0), cyan, 1.3, true)
    draw_line(center + Vector2(0, -13), center + Vector2(0, 13), cyan, 1.3, true)
    draw_circle(center, 2.8, Color(0.78, 0.98, 1.0, 0.9))
    var horizon_y: float = s.y * 0.49
    for i in range(-5, 6):
        var x: float = s.x * 0.5 + float(i) * 72.0
        var line_len: float = 11.0 if i % 2 == 0 else 5.0
        draw_line(Vector2(x, horizon_y - line_len * 0.5), Vector2(x, horizon_y + line_len * 0.5), muted, 1.0, true)
    var corners := [
        [Vector2(24, 91), Vector2(24, 155), Vector2(108, 155)],
        [Vector2(s.x - 24, 91), Vector2(s.x - 24, 155), Vector2(s.x - 108, 155)],
        [Vector2(24, s.y - 175), Vector2(24, s.y - 202), Vector2(93, s.y - 202)],
        [Vector2(s.x - 24, s.y - 175), Vector2(s.x - 24, s.y - 202), Vector2(s.x - 93, s.y - 202)]
    ]
    for points in corners:
        draw_line(points[0], points[1], muted, 2.0, true)
        draw_line(points[1], points[2], muted, 2.0, true)
    if warp_amount > 0.01:
        draw_rect(Rect2(Vector2.ZERO, s), Color(0.16, 0.73, 1.0, warp_amount * 0.12))
        for j in range(96):
            var angle: float = float(j) * 2.39996 + phase * 0.09
            var offset: float = 55.0 + float((j * 37) % 230)
            var dir := Vector2(cos(angle), sin(angle))
            draw_line(center + dir * offset, center + dir * (offset + 280.0 * warp_amount), Color(0.37, 0.85, 1.0, 0.12 + warp_amount * 0.72), 1.2 + warp_amount * 1.9, true)
