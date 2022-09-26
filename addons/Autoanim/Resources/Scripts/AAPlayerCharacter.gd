tool
class_name PlayerCharacter
extends BaseCharacter

func _ready() -> void:
	is_player = true
	if !Engine.is_editor_hint:
		self.state = States.IDLE
	animTree.set("parameters/Idle/blend_position", Vector2(0,1))
	animTree.set("parameters/Run/blend_position", Vector2(0,1))


#static func _get_direction() -> Vector2:
#	return Vector2(
#		(Input.get_action_strength("right") - Input.get_action_strength("left")),
#		Input.get_action_strength("down") - Input.get_action_strength("up")
#	).normalized()
#	return Vector2.ZERO
	
func _physics_process(delta: float) -> void:
	if !Engine.is_editor_hint():
		input_vector = get_direction()
		
		if state == States.RUN:
			animTree.set("parameters/Idle/blend_position", input_vector)
			animTree.set("parameters/Move/blend_position", input_vector)
			animState.travel("Move")
			velocity += input_vector * acceleration * delta * SPEED_FACTOR
			velocity = velocity.clamped(max_speed * delta * SPEED_FACTOR)
			
		else:
			animState.travel("Idle")
			velocity = Vector2.ZERO
			
		move_and_collide(velocity)

func _set_sprite_sheet(state :int) -> void:
	if !Engine.is_editor_hint():
		sprite.texture = load(animation_data.states_details_map[States.keys()[state].capitalize()]["texture"])

func _unhandled_input(event :InputEvent) -> void:
	if !Engine.is_editor_hint():
		if event:
			if is_player:
				if input_vector != Vector2.ZERO:
					self.state = States.RUN
				else:
					self.state = States.IDLE
#		_set_sprite_sheet(state)


