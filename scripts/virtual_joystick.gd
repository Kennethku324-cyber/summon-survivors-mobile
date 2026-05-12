extends Control

@export var joystick_radius: float = 80.0
@export var thumb_radius: float = 30.0
@export var deadzone: float = 0.15

var touch_index: int = -1
var thumb_offset: Vector2 = Vector2.ZERO
var current_dir: Vector2 = Vector2.ZERO
var mouse_pressed: bool = false

func _ready():
	custom_minimum_size = Vector2(joystick_radius * 2, joystick_radius * 2)

func _input(event):
	if not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		if event.pressed and _is_in_joystick_area(event.position):
			touch_index = event.index
			_update_joystick(event.position)
		elif not event.pressed and event.index == touch_index:
			_reset_joystick()
	elif event is InputEventScreenDrag and event.index == touch_index:
		_update_joystick(event.position)
	elif event is InputEventMouseButton:
		if event.pressed and _is_in_joystick_area(event.position):
			mouse_pressed = true
			_update_joystick(event.position)
		elif not event.pressed and mouse_pressed:
			_reset_joystick()
			mouse_pressed = false
	elif event is InputEventMouseMotion and mouse_pressed:
		_update_joystick(event.position)

func _is_in_joystick_area(screen_pos: Vector2) -> bool:
	var local = _to_local(screen_pos)
	return local.length() <= joystick_radius * 1.5

func _to_local(screen_pos: Vector2) -> Vector2:
	var gp = get_global_position()
	var gs = get_global_scale()
	return (screen_pos - gp) / gs - Vector2(joystick_radius, joystick_radius)

func _update_joystick(screen_pos: Vector2):
	var local = _to_local(screen_pos)
	var clamped = local.limit_length(joystick_radius)
	thumb_offset = clamped
	var dir = clamped / joystick_radius
	current_dir = dir if dir.length() > deadzone else Vector2.ZERO
	_update_actions()
	queue_redraw()

func _reset_joystick():
	thumb_offset = Vector2.ZERO
	current_dir = Vector2.ZERO
	touch_index = -1
	mouse_pressed = false
	_update_actions()
	queue_redraw()

func _update_actions():
	var x = current_dir.x
	var y = current_dir.y
	if x < -deadzone:
		Input.action_press("move_left", -x)
		Input.action_release("move_right")
	elif x > deadzone:
		Input.action_press("move_right", x)
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")
	if y < -deadzone:
		Input.action_press("move_up", -y)
		Input.action_release("move_down")
	elif y > deadzone:
		Input.action_press("move_down", y)
		Input.action_release("move_up")
	else:
		Input.action_release("move_up")
	Input.action_release("move_down")

func _draw():
	var center = Vector2(joystick_radius, joystick_radius)
	draw_circle(center, joystick_radius, Color(1, 1, 1, 0.3))
	draw_arc(center, joystick_radius, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
	draw_circle(center + thumb_offset, thumb_radius, Color(1, 1, 1, 0.7))
	draw_circle(center + thumb_offset, thumb_radius * 0.5, Color(1, 1, 1, 0.85))
