tool
class_name AASavers
extends Node

var vars_tracker := load("res://addons/Autoanim/Resources/AutoAnimVarsTracker.tres")
var base_character_path := "res://addons/Autoanim/CharacterBases/Base/BaseCharacter.tscn"

func save_character_adr(adr :AnimationData) -> bool:
	var result := ResourceSaver.save(
			vars_tracker.CharacterDirectory.plus_file(
				adr.character_name.replace(" ","") + "AnimationData.tres"),
				adr)
	if result != OK:
		printerr( "SAVING %s's AnimationData FAILED" % adr.character_name)
		return false
	return true


func save_vars_tracker() -> bool:
	var result := ResourceSaver.save("res://addons/Autoanim/Resources/AutoAnimVarsTracker.tres", vars_tracker)
	if result != OK:
		printerr("SAVINGS AutoAnimVarsTracker FAILED!")
		return false
#	print("SAVED VARS TRACKER")
	return true


func pack_and_save_character(character :BaseCharacter, inherited :bool = true) -> bool:
	var character_name := character.character_name
	var packed_character :PackedScene
	if !inherited:
		packed_character = PackedScene.new()
#		print("Not Inherited: ", packed_character._bundled)
	else:
		packed_character = create_inherited_scene(load(base_character_path), character.character_name)
#		print("Inherited: ", packed_character._bundled)
	
	var tmp_path := _make_random_path(".tscn")
	var char_filepath :String = vars_tracker.CharacterDirectory.plus_file(character_name.replace(" ","") + ".tscn")
	while ResourceLoader.has_cached(tmp_path):
		tmp_path = _make_random_path(".tscn")
		print(tmp_path)
		
	# Return false if the Character Directory is not set
	if !vars_tracker.CharacterDirectory:
		printerr("Character Directory is invalid")
		return false
	
	# Return false if character fails to pack
	if !packed_character.pack(character) == OK:
		printerr("Character failed to pack.")
		return false
	
	# Return false if the character fails to save
	if !ResourceSaver.save(char_filepath, packed_character, 64) == OK:
		print(ResourceSaver.save(char_filepath, packed_character, 64))
		
		printerr("Character failed to save. Path :%s | Character: %s" % [char_filepath, packed_character])
		return false
#	print("Character '%s' saved." % character.character_name)
#	print("'%s' script: " % character.get_script())
#	print("Inheritance: ", packed_character._bundled)
	return true


static func _make_random_path(file_type :String) -> String:
	return "res://addons/Autoanim/Resources/temp/" + str(randi()) + file_type


func create_inherited_scene(inherits :PackedScene, root_name := "Scene") -> PackedScene:
	var scene := PackedScene.new()
	scene._bundled = {"base_scene": 0, "conn_count": 0, "conns": [], "editable_instances": [], "names": [root_name], "node_count": 1, "node_paths": [], "nodes": [-1, -1, 2147483647, 0, -1, 0, 0], "variants": [inherits], "version": 2}
	return scene
