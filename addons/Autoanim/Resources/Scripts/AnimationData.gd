tool
class_name AnimationData
extends Resource

export var character_name = ""
export var states := []
export var directions := []
export var character_animations := ["RESET"]
export var char_file_name = ""

# This is a dictionary of the animation details for each state keyed by the states name.
export var states_details_map := {}
# USE THE FOLLOWING FORMAT
#	{ state = {
#		anim_step : 0.0,
#		anim_length : 0.0,
#		texture : res://Texture,
#		vframes : 0,
#		hframes : 0,
#		looping : false,
#		frames : 0,
#		frames_on_texture : [0,1,2,3,4,5...]
#		sprite_height: 0,
#		sprite_width : 0
#		}
#	}



## SETTERS AND GETTERS

func set_property_value(property :String, value) -> void:
	match property:
		"character_name":
			character_name = value
		"states":
			states = value
		"character_animations":
			character_animations = value
		"char_file_name":
			char_file_name = value
		"states_details_map":
			states_details_map = value
		"directions":
			directions = value
#		"anim_step":
#			anim_step = value
#		"anim_length":
#			anim_length = value
		_:
			printerr("Property '%s' Not Found on Animation Data! Cannot Set." % property)
			printerr("You may need to update your AnimationDataResource on ", character_name)


func get_property_value(property :String):
	match property:
		"character_name":
			return character_name
		"states":
			return states
		"character_animations":
			return character_animations
		"char_file_name":
			return char_file_name
		"states_details_map":
			return states_details_map
		"directions":
			return directions
#		"anim_step":
#			return anim_step
#		"anim_length":
#			return anim_length
			
		_:
			printerr("Property '%s' Not Found on Animation Data! Cannot Get!" % property)
			printerr("You may need to update your AnimationDataResource on ", character_name)


