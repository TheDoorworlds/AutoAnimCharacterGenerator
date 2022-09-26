tool
class_name VarsTracker
extends Resource

enum DirectionSets { FDTD = 0, FDIS = 1, EDTD = 2, TDPF = 3 }
enum Directions { SOUTH = 0, SOUTHEAST = 1, EAST = 2, NORTHEAST = 3, NORTH = 4, NORTHWEST = 5, WEST = 6, SOUTHWEST = 7 }

# CHARACTER MANAGEMENT AND DIRECTORIES
export var CharacterList := [] 
export var CharacterDirectory := ""
export var AssetDirectory := ""
export var FDTDCharacterBasePath := "res://addons/Autoanim/CharacterBases/FDTD/FDTDCharacter.tscn"
export var FDISCharacterBasePath := "res://addons/Autoanim/CharacterBases/FDIS/FDISCharacter.tscn"
export var EDTDCharacterBasePath := "res://addons/Autoanim/CharacterBases/EDTD/EDTDCharacter.tscn"
export var TDPFCharacterBasePath := "res://addons/Autoanim/CharacterBases/TDPF/TDPFCharacter.tscn"

# DEFAULT VALUES
export var DefaultAnimationStatesList := []
export var DefaultSpriteHeight := 0
export var DefaultSpriteWidth := 0
export var DefaultDirectionSet := 0 setget set_default_direction_set
export var DefaultDirections := []
export var DefaultAnimationStep := 0.1
export var DefaultAnimationLength := 0.8


# REFERENCE VARS
func set_default_direction_set(value) -> void:
	DefaultDirectionSet = value
	match value:
		DirectionSets.FDTD:
			DefaultDirections = [
				Directions.SOUTH,
				Directions.EAST,
				Directions.NORTH,
				Directions.WEST
			]
		DirectionSets.FDIS:
			DefaultDirections = [
				Directions.SOUTHEAST,
				Directions.NORTHEAST,
				Directions.NORTHWEST,
				Directions.SOUTHWEST
			]
		DirectionSets.EDTD:
			DefaultDirections = [
				Directions.SOUTH,
				Directions.SOUTHEAST,
				Directions.EAST,
				Directions.NORTHEAST,
				Directions.NORTH,
				Directions.NORTHWEST,
				Directions.WEST,
				Directions.SOUTHWEST
			]
		DirectionSets.TDPF:
			DefaultDirections = [
				Directions.EAST,
				Directions.WEST
			]
		_:
			DefaultDirections = []
			
#	ResourceSaver.save("res://addons/Autoanim/Resources/AutoAnimVarsTracker.tres", self)
#	print(DefaultDirections)
	
	
# SAVING FUNCTIONS
func save_character_adr(character :BaseCharacter) -> void:
	assert(
		ResourceSaver.save(
			CharacterDirectory.plus_file(
				character.character_name.replace(" ","") + "AnimationData.tres"),
				character.animation_data)
			== OK,
		"SAVING %s AnimationData FAILED" % character.character_name)

func save_project_vars_resource() -> void:
	assert(
		ResourceSaver.save(
			"res://addons/Autoanim/Resources/AutoAnimVarsTracker.tres", self
		),
		"SAVINGS PROJECT VARIABLES FAILED!"
	)

func pack_and_save_character(character :BaseCharacter) -> bool:
	var character_name := character.character_name
	var packed_character = PackedScene.new()
	var tmp_path := _make_random_path(".tscn")
	var char_filepath := CharacterDirectory.plus_file(character_name.replace(" ",""))
	while ResourceLoader.has_cached(tmp_path):
		tmp_path = _make_random_path(".tscn")
		print(tmp_path)
	# Return false if the Character Directory is not set
	if !CharacterDirectory:
		printerr("Character Directory is invalid")
		return false
	
	# Return false if character fails to pack
	if !packed_character.pack(character) == OK:
		printerr("Character failed to pack.")
		return false
	
	ResourceSaver.save(char_filepath, packed_character, 64)
	return true

static func _make_random_path(file_type :String) -> String:
	return "res://addons/Autoanim/Resources/temp/" + str(randi()) + file_type
