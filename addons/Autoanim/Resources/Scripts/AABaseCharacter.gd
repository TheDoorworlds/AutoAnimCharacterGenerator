tool
class_name BaseCharacter
extends KinematicBody2D

# Constants
const SPEED_FACTOR := 12

# Enums

## Add your desired states to this enum
enum States {IDLE, MOVE, WANDER}


# Constants
const WANDER_CONTROLLER :String = "res://addons/Autoanim/Scenes/wander_timer.tscn"

# Node References
onready var animState :AnimationNodeStateMachinePlayback
onready var animStateMachine :AnimationNodeStateMachine
onready var wanderController :Node2D
onready var animPlayer :AnimationPlayer = $CharacterSprite/SpriteAnimationPlayer
onready var animTree :AnimationTree = $AnimationTree
onready var sprite :Sprite = $CharacterSprite

# Export Vars
export var character_name := "Default"
export(int) var acceleration := 10
export(int) var max_speed := 15
export var is_player :bool = false
export(Resource) var animation_data
export(States) var state setget set_character_state

# Public vars
var velocity := Vector2.ZERO
var direction_set :int
var input_vector :Vector2



func _ready() -> void:
	if !animTree:
		animTree = $AnimationTree
	if !animPlayer:
		animPlayer = $CharacterSprite/SpriteAnimationPlayer
	if !sprite:
		sprite = $CharacterSprite
	if !animState:
		animState = animTree.get("parameters/playback")
	if !animStateMachine:
		animStateMachine = animTree.tree_root
	animTree.set("parameters/Idle/blend_position", Vector2(0,1))
	animTree.set("parameters/Move/blend_position", Vector2(0,1))
	if !Engine.is_editor_hint():
		self.state = States.IDLE
		if !is_player:
			wanderController = load(WANDER_CONTROLLER).instance()
			add_child(wanderController)
			wanderController.timer.connect("timeout", self, "pick_random_idle_state", [[States.IDLE, States.WANDER]])


# Add in a match case for each of your states
func _physics_process(delta: float) -> void:
	if !Engine.is_editor_hint():
		
		if !is_player:
#			input_vector = get_direction()
#		else:
			input_vector = global_position.direction_to(wanderController.target_position)
		match state:
			States.MOVE:
				animTree.set("parameters/Idle/blend_position", input_vector)
				animTree.set("parameters/Move/blend_position", input_vector)
				animState.travel("Move")
				velocity += input_vector * acceleration * delta * SPEED_FACTOR
				velocity = velocity.limit_length(max_speed * delta * SPEED_FACTOR)
			States.IDLE:
				animState.travel("Idle")
				velocity = Vector2.ZERO
#				if !is_player:
#					pick_random_idle_state([States.IDLE, States.WANDER])
			States.WANDER:
				animTree.set("parameters/Idle/blend_position", input_vector)
				animTree.set("parameters/Move/blend_position", input_vector)
				animState.travel("Move")
				if !is_player:
					var direction :Vector2 = global_position.direction_to(wanderController.target_position)
					velocity = velocity.move_toward(direction * max_speed, acceleration * delta)
					if global_position.distance_to(wanderController.target_position) <= 4:
						pick_random_idle_state()
		move_and_collide(velocity)


func _unhandled_input(event :InputEvent) -> void:
	if !Engine.is_editor_hint():
		if event:
			if is_player:
				input_vector = get_direction()
				if input_vector != Vector2.ZERO:
					self.state = States.MOVE
				else:
					self.state = States.IDLE



## DO NOT CHANGE THESE FUNCTIONS!
	# These functions are core to the characters built with AutoAnim working properly.
	# A default copy of these functions is available in the DefaultScripts folder
func set_character_state(new_state :int) -> void:
	var state_name :String = States.keys()[new_state].capitalize()
	if new_state == States.WANDER:
		state_name = "Move"
	state = new_state
	if !Engine.is_editor_hint():
		sprite.hframes = animation_data.states_details_map[state_name]["hframes"]
		sprite.vframes = animation_data.states_details_map[state_name]["vframes"]
		sprite.texture = load(animation_data.states_details_map[state_name]["texture"])


static func get_direction() -> Vector2:
	return Vector2(
		(Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	).normalized()


func pick_random_idle_state(state_list :Array = [States.IDLE, States.WANDER]) -> void:
	state_list.shuffle()
	self.state = state_list[0]
	wanderController.timer.wait_time = rand_range(1, 3)
	wanderController.timer.start()
