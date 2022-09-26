tool
class_name AnimationGenerator
extends Node

## ENUMS
enum Directions { SOUTH, SOUTHEAST, EAST, NORTHEAST, NORTH, NORTHWEST, WEST, SOUTHWEST }


# Errors regarding the creation of new characters
enum CHARACTER_CREATION_ERRORS { 
	PROBLEM_ADDING_CHARACTER = 0, # GENERIC catch-all error.  Mod author will attempt to track down specific causes and define out all errors.
	PROBLEM_SAVING_CHARACTER = 1, # Character or Charater Animation Data did not save to the directory properly.
	PROBLEM_SAVING_VARSTRACKER = 2, # AutoAnimVarsTracker did not save properly
	INVALID_DIRECTORY = 3, # The CharacterDirectory is invalid.  Assign a valid
	CHARACTER_ALREADY_EXISTS = 4,  # Character already exists in the VarsTracker CharacterList.  If the character doe snot exist in the Character Directory, inspect the Resources/AutoAnimVarsTracker.tres:CharacterList for issues.
	PROBLEM_PACKING_CHARCTER = 5, # There was a problem packng the character.
	INVALID_NAME = 6 # Emitted when the name provided is empty or will create an invalid filename
		}

## SIGNALS
signal finished_adding_children_to_new_character
signal character_succesfully_added(character_name)
signal character_not_added(reason, originating_script)
signal animations_created
signal save_vars_tracker

## INTERNAL VARS
var vars_tracker :VarsTracker 

## SCENE & RESOURCE REFERENCES
export var FDTDCharacterBasePath := "res://addons/Autoanim/CharacterBases/FDTD/FDTDCharacter.tscn"
export var FDISCharacterBasePath := "res://addons/Autoanim/CharacterBases/FDIS/FDISCharacter.tscn"
export var EDTDCharacterBasePath := "res://addons/Autoanim/CharacterBases/EDTD/EDTDCharacter.tscn"
export var TDPFCharacterBasePath := "res://addons/Autoanim/CharacterBases/TDPF/TDPFCharacter.tscn"

func setup_new_character(character_name :String, direction_set :String = "") -> BaseCharacter:
	
	## Check if the Character List already contains this character and verify validity of name
	if vars_tracker.CharacterList.has(character_name) or character_name == "" or !character_name.replace(" ", "").is_valid_filename():
		if character_name == "":
			printerr("No name provided, please provide a valid name.")
			emit_signal("character_not_added", CHARACTER_CREATION_ERRORS.INVALID_NAME, self)
		elif vars_tracker.CharacterList.has(character_name):
			printerr("   Character %s Already Exists" % character_name)
			emit_signal("character_not_added", CHARACTER_CREATION_ERRORS.CHARACTER_ALREADY_EXISTS, self)
		elif !character_name.replace(" ", "").is_valid_filename():
			printerr("Name has invalid characters.  Please only use alpha-numeric and hyphens.")
			emit_signal("character_not_added", CHARACTER_CREATION_ERRORS.INVALID_NAME, self)
		else:
			printerr("   Character %s Already Exists" % character_name)
			emit_signal("character_not_added", CHARACTER_CREATION_ERRORS.CHARACTER_ALREADY_EXISTS, self)
		return null
		
	else:
		# Create new instance of base character
		var base_character
		match vars_tracker.DefaultDirectionSet:
			vars_tracker.DirectionSets.FDTD:
				base_character = load(FDTDCharacterBasePath)
			vars_tracker.DirectionSets.FDIS:
				base_character = load(FDISCharacterBasePath)
			vars_tracker.DirectionSets.EDTD:
				base_character = load(EDTDCharacterBasePath)
			vars_tracker.DirectionSets.TDPF:
				base_character = load(TDPFCharacterBasePath)
			_:
				printerr("Invalid Direction Set.")
		var new_character :BaseCharacter = base_character.instance()

		# Have new character take ownership of all of its nodes (for saving)
		own(new_character, new_character)
		
		# Set up the new character with its variables
		new_character.name = character_name.replace(" ", "")
		new_character.character_name = character_name
		new_character.direction_set = vars_tracker.DefaultDirectionSet
		return new_character



# ANIMATION CREATION FUNCTIONS

func create_animations(character :BaseCharacter, state :String) -> void:
	character.animPlayer = character.get_node("CharacterSprite/SpriteAnimationPlayer")
	var frame := 0
	var adr :AnimationData = character.animation_data
	# Verify that the state exists
	if !adr.states_details_map.has(state):
		printerr("State '%s' does not exist in the character map.  Please ensure the desired state is in the AnimationTree on %s." % [ state, character.character_name ])
		return
	
	# Create a dictionary for EOA for the adr state_details_map
	var details :Dictionary = adr.states_details_map[state]
	
	# Grab the texture
	var state_texture :Texture = load(details["texture"])
	
	# Reference the sprite size
	var sprite_size :Vector2 = Vector2(details.sprite_width, details.sprite_height)
	
	# Iterate over directions to create animations for each direction
	for direction in adr.directions:
#		print("   Working on '%s'." % direction)
		
		## CREATE A NEW ANIMATION
		var anim_to_add :Animation
		
		#Create a name for the animation by concatinating the state and the direction
		var anim_name :String = state.capitalize() + direction.capitalize()
		
		#Check if the animation exists and if so, remove it.
		if character.animPlayer.has_animation(anim_name):
			character.animPlayer.remove_animation(anim_name)
#			print("Removed animation: ", anim_name)
		anim_to_add = Animation.new()
		
		# Set the animation to looping or not
		if adr.states_details_map[state]["looping"]:
			anim_to_add.loop = true
		
		# Add new tracks with individual variables for EOA, may update later
		var vframes_track := anim_to_add.add_track(Animation.TYPE_VALUE)
		var hframes_track := anim_to_add.add_track(Animation.TYPE_VALUE)
		var frame_track := anim_to_add.add_track(Animation.TYPE_VALUE)
#		var texture_track := anim_to_add.add_track(Animation.TYPE_VALUE)
		
		# Array of all tracks that will be visted over the creation of the animation
		var tracks := [vframes_track, hframes_track, frame_track]
		
		# Start the animation at 0.0 timestamp
		var timestamp := 0.0
		
		# The animation length pulled from the state details map on the adr
		var anim_length :float = details["anim_length"]
		anim_to_add.length = anim_length
		
		# Calculate the number of rows (vframes) and columns (hframes) in the provided texture
		var vframes :int = details.vframes
		var hframes :int = details.hframes
		
		# Set up the animation step
		var anim_step :float = details.anim_step
		
		# Set the update mode to discrete
		for i in tracks.size():
				if anim_to_add.track_get_type(i) == Animation.TYPE_VALUE:
					anim_to_add.value_track_set_update_mode(i, Animation.UPDATE_DISCRETE)
					
		# Set up the path for each track
		anim_to_add.track_set_path(vframes_track, ".:vframes")
		anim_to_add.track_set_path(hframes_track, ".:hframes")
#		anim_to_add.track_set_path(texture_track, ".:texture")
		anim_to_add.track_set_path(frame_track, ".:frame")
		
		# Set up the initial state of the animation on a keyframe at 0.0
		anim_to_add.track_insert_key(vframes_track, 0.0, vframes)
		anim_to_add.track_insert_key(hframes_track, 0.0, hframes)
#		anim_to_add.track_insert_key(texture_track, 0.0, state_texture)
		
		# Set up the frames animation keyframes
		for i in hframes:
			anim_to_add.track_insert_key(frame_track, timestamp, frame)
			timestamp += anim_step
			frame += 1
		character.animPlayer = character.get_node("CharacterSprite/SpriteAnimationPlayer")
		character.animPlayer.add_animation(anim_name, anim_to_add)
#		print("Animation Added: %s, %s" % [anim_name, anim_to_add])
	_set_blend_points_to_default(character, state, adr.directions, adr)


func _set_blend_points_to_default(character :BaseCharacter, state :String, directions :Array, adr :AnimationData) -> void:
	# Set up the animation tree blend space for the state
	character.animTree = character.get_node("AnimationTree")
	var anim_tree :AnimationTree = character.animTree
	var state_machine :AnimationNodeStateMachine = anim_tree.tree_root
	assert(state_machine, "No State Machine found on %s." % character.character_name)
	
	var blend_space :AnimationNodeBlendSpace2D = state_machine.get_node(state)
	blend_space.auto_triangles = true
	blend_space.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_DISCRETE_CARRY
	
	# Set the animation's blend position base on direcion of the animation
	var blend_position := Vector2.ZERO
#	print("Starting number of blend points: ", blend_space.get_blend_point_count())
	
	# Removes any existing blend points to ensure no doubling
	if blend_space.get_blend_point_count() > 0:
#		print("Blend points exist in blend space (%s)" % blend_space.get_blend_point_count())
		for i in blend_space.get_blend_point_count():
#			print("Removing point ", i)
			blend_space.remove_blend_point(0)
	
	if blend_space.get_blend_point_count() > 0:
		printerr("Did not successfully remove all blend points!")
		return
	
	# Create an index value for adding blend points to the blendspace
	var bp_index :int = 0
	
	# Adds a blend point to a specific Vector2 position based on the direction names
	for direction in adr.directions:
		match direction.capitalize():
			"South" :
				blend_position = Vector2(0, 1)
			"Southeast" :
				blend_position = Vector2(0.5, 0.5)
			"East" :
				blend_position = Vector2(1, 0)
			"Northeast" :
				blend_position = Vector2(0.5, -0.5)
			"North" :
				blend_position = Vector2(0, -1)
			"Northwest" :
				blend_position = Vector2(-0.5, -0.5)
			"West" :
				blend_position = Vector2(-1, 0)
			"Southwest" :
				blend_position = Vector2(-0.5, 0.5)
			_:
				printerr("Direction %s not found (AnimationGenerator.gd).  Please check the directions array on %s's ADR." % [direction, character.character_name])
			
		var blend_point :AnimationNodeAnimation = AnimationNodeAnimation.new()
#		print("New blend point: ", blend_point)
		blend_point.animation = state.capitalize() + direction.capitalize()
		blend_space.add_blend_point(blend_point, blend_position, bp_index)
		bp_index += 1
#		print("New number of blend points in blend space: ", blend_space.get_blend_point_count())
	emit_signal("animations_created")


func clear_all_animations(character :BaseCharacter, state :String = "All") -> bool:
	var anim_player :AnimationPlayer = character.get_node("CharacterSprite/SpriteAnimationPlayer")
	var animation_list :PoolStringArray = anim_player.get_animation_list()
	
	if state == "All":
		for animation in animation_list:
			anim_player.remove_animation(animation)
		if anim_player.get_animation_list().size() > 0:
			printerr("Failed to remove all animations on AnimationGenerator.gd")
			return false
	else:
		for animation in animation_list:
			if animation.begins_with(state):
				anim_player.remove_animation(animation)
		for animation in anim_player.get_animation_list():
			if animation.begins_with(state):
				printerr("Failed to remove all animations for %s on AnimationGenerator.gd" % state)
				return false
	return true



## SUPPORT FUNCTIONS

func _calculate_frames(texture: Texture, sprite_size :Vector2) -> Vector2:
	var frame_setup :Vector2 = Vector2.ZERO
	frame_setup.x = int(texture.get_size().x / sprite_size.x)
	frame_setup.y = int(texture.get_size().y / sprite_size.y)
	return frame_setup

## SAVING FUNCTIONS
static func own(node :Node, new_owner : Node) -> void:
	if not node == new_owner and (not node.owner or node.filename):
		node.owner = new_owner
	if node.get_child_count():
		for child in node.get_children():
			own(child, new_owner)

## LOAD/SAVE BUG FIX FUNCTIONS
static func make_random_path(file_type :String) -> String:
	return "res://addons/Autoanim/Resources/temp/" + str(randi()) + file_type
	
static func character_exists(path :String) -> bool:
	return ResourceLoader.exists(path)

