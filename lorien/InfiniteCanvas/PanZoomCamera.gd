extends Camera2D

signal zoom_changed(value)
signal position_changed(value)

const ZOOM_INCREMENT := 1.1 	# Feel free to modify (Krita uses sqrt(2))
const MIN_ZOOM_LEVEL := 0.1
const MAX_ZOOM_LEVEL := 100
const KEYBOARD_PAN_CONSTANT := 20

var _is_input_enabled := true

var _pan_active := false
var _zoom_active := false

var _prev_event:InputEventScreenDrag = null

var _current_zoom_level := 2.0
var _start_mouse_pos := Vector2(0.0, 0.0)

# -------------------------------------------------------------------------------------------------
func set_zoom_level(zoom_level: float) -> void:
	_current_zoom_level = _to_nearest_zoom_step(zoom_level)
	zoom = Vector2(_current_zoom_level, _current_zoom_level)

# -------------------------------------------------------------------------------------------------
func do_center(screen_space_center_point: Vector2) -> void:
	var screen_space_center := get_viewport().get_size() / 2
	var delta := screen_space_center - screen_space_center_point
	get_viewport().warp_mouse(screen_space_center)
	_do_pan(delta)

# -------------------------------------------------------------------------------------------------
func multi_touch_event(event: InputEventScreenDrag):
	# First touch event
	if _prev_event == null:
		_prev_event = event
		return

	# Calculate relative movement (zooming in or out); regardless of which finger touch is current event
	var diff_old = (event.position + event.relative) - (_prev_event.position + _prev_event.relative)
	var diff_new = event.position - _prev_event.position
	var diff = diff_old.length_squared() - diff_new.length_squared()
	diff = max(diff, -1000) if diff < 0 else min(diff, 1000)

	# If both fingers are moving in the same direction (panning), the difference is small
	if abs(diff) < 500:
		_do_pan(event.relative)
	else:
		var acceleration = max(min(log(event.speed.length()) / 2, 3), 0)
		var delta = (diff / 25000) * _current_zoom_level * acceleration

		# Mouse position is locked on the first finger; determine if current event is that finger
		var mouse_pos = get_local_mouse_position()
		var dist_mouse_event = mouse_pos.distance_squared_to(event.position + event.relative)
		var dist_mouse_prev_event = mouse_pos.distance_squared_to(_prev_event.position + _prev_event.relative)

		if dist_mouse_event < dist_mouse_prev_event:
			var calc_pos = get_local_mouse_position() - diff_new * _current_zoom_level
			_zoom_canvas(min(_current_zoom_level - delta, 7), (mouse_pos + calc_pos) / 2)

	_prev_event = event

# -------------------------------------------------------------------------------------------------
func tool_event(event: InputEvent) -> void:
	if _is_input_enabled:
		if event is InputEventScreenDrag:
			multi_touch_event(event)

		if event is InputEventMouseButton:

			# Scroll wheel up/down to zoom
			if event.button_index == BUTTON_WHEEL_DOWN:
				if event.pressed:
					_do_zoom_scroll(1)
			elif event.button_index == BUTTON_WHEEL_UP:
				if event.pressed:
					_do_zoom_scroll(-1)
			
			# MMB press to begin pan; ctrl+MMB press to begin zoom
			if event.button_index == BUTTON_MIDDLE:
				if !event.control:
					_pan_active = event.is_pressed()
					_zoom_active = false
				else:
					_zoom_active = event.is_pressed()
					_pan_active = false
					_start_mouse_pos = get_local_mouse_position()
					
		elif event is InputEventMouseMotion:
			# MMB drag to pan; ctrl+MMB drag to zoom
			if _pan_active:
				_do_pan(event.relative)
			elif _zoom_active:
				_do_zoom_drag(event.relative.y)
		
		elif Utils.event_pressed_bug_workaround("canvas_zoom_in", event):
			_do_zoom_scroll(-1)
			get_tree().set_input_as_handled()
		
		elif Utils.event_pressed_bug_workaround("canvas_zoom_out", event):
			_do_zoom_scroll(1)
			get_tree().set_input_as_handled()
		
		elif Utils.event_pressed_bug_workaround("canvas_pan_left", event):
			_do_pan(-Vector2.LEFT * KEYBOARD_PAN_CONSTANT)
			get_tree().set_input_as_handled()

		elif Utils.event_pressed_bug_workaround("canvas_pan_right", event):
			_do_pan(-Vector2.RIGHT * KEYBOARD_PAN_CONSTANT)
			get_tree().set_input_as_handled()

		elif Utils.event_pressed_bug_workaround("canvas_pan_up", event):
			_do_pan(-Vector2.UP * KEYBOARD_PAN_CONSTANT)
			get_tree().set_input_as_handled()

		elif Utils.event_pressed_bug_workaround("canvas_pan_down", event):
			_do_pan(-Vector2.DOWN * KEYBOARD_PAN_CONSTANT)
			get_tree().set_input_as_handled()

# -------------------------------------------------------------------------------------------------
func _do_pan(pan: Vector2) -> void:
	offset -= pan * _current_zoom_level
	emit_signal("position_changed", offset)

# -------------------------------------------------------------------------------------------------
func _do_zoom_scroll(step: int) -> void:
	var new_zoom = _to_nearest_zoom_step(_current_zoom_level) * pow(ZOOM_INCREMENT, step)
	_zoom_canvas(new_zoom, get_local_mouse_position())

# -------------------------------------------------------------------------------------------------
func _do_zoom_drag(delta: float) -> void:
	delta *= _current_zoom_level / 100
	_zoom_canvas(_current_zoom_level + delta, _start_mouse_pos)

# -------------------------------------------------------------------------------------------------
func _zoom_canvas(target_zoom: float, anchor: Vector2) -> void:
	target_zoom = clamp(target_zoom, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)
	
	if target_zoom == _current_zoom_level:
		return

	# Pan canvas to keep content fixed under the cursor
	var zoom_center = anchor - offset
	var ratio = 1.0 - target_zoom / _current_zoom_level
	offset += zoom_center * ratio
	
	_current_zoom_level = target_zoom
	
	zoom = Vector2(_current_zoom_level, _current_zoom_level)
	emit_signal("zoom_changed", _current_zoom_level)

# -------------------------------------------------------------------------------------------------
func _to_nearest_zoom_step(zoom_level: float) -> float:
	zoom_level = clamp(zoom_level, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)
	zoom_level = round(log(zoom_level) / log(ZOOM_INCREMENT))
	return pow(ZOOM_INCREMENT, zoom_level)

# -------------------------------------------------------------------------------------------------
func enable_input() -> void:
	_is_input_enabled = true

# -------------------------------------------------------------------------------------------------

func disable_input() -> void:
	_is_input_enabled = false
	
# -------------------------------------------------------------------------------------------------
func xform(pos: Vector2) -> Vector2:
	return (pos * zoom) + offset
