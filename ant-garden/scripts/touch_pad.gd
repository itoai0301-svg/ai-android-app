extends Control

signal direction_changed(value: Vector2)
var finger := -1
var direction := Vector2.ZERO
var pressed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_handle)
	queue_redraw()

func _handle(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger < 0:
			finger = event.index
			pressed = true
			update_point(event.position)
			accept_event()
		elif event.index == finger and not event.pressed:
			release()
			accept_event()
	elif event is InputEventScreenDrag and event.index == finger:
		update_point(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		if pressed: update_point(event.position)
		else: release()
		accept_event()
	elif event is InputEventMouseMotion and pressed and finger < 0:
		update_point(event.position)
		accept_event()

func update_point(point: Vector2) -> void:
	direction = ((point - size / 2) / 54.0).limit_length()
	if direction.length() < 0.13: direction = Vector2.ZERO
	direction_changed.emit(direction)
	queue_redraw()

func release() -> void:
	finger = -1
	pressed = false
	direction = Vector2.ZERO
	direction_changed.emit(direction)
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	draw_circle(center, 66.0, Color(0.06,0.16,0.12,0.36), true, -1.0, true)
	draw_arc(center, 66.0, 0, TAU, 64, Color(0.94,0.97,0.81,0.3), 1.5, true)
	draw_circle(center, 43.0, Color(0.7,0.8,0.55,0.10), true, -1.0, true)
	draw_circle(center+direction*39.0+Vector2(0,3), 26.0, Color(0.04,0.13,0.09,0.24), true, -1.0, true)
	draw_circle(center+direction*39.0, 26.0, Color("#f0e6b9"), true, -1.0, true)
	draw_circle(center+direction*39.0+Vector2(-5,-7), 12.0, Color(1,1,0.9,0.2), true, -1.0, true)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.index == finger and not event.pressed:
		release()
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and pressed:
		release()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: release()

