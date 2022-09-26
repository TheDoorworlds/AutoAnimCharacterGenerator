## THIS SCRIPT HANDLES ALL COMMUNICATION BETWEEN THE UI (AutoAnimsMain.tscn) AND THE ANIMATION GENERATOR (AnimationGenerator.gd)
tool
extends EditorPlugin

## ENUMS
enum DirectionSets {FDTD = 0, FDIS = 1, EDTD = 2, TDPF = 3}

## SCENE AND RESOURCE REFERENCES
 # Main interface for the plugin
var main = preload("res://addons/Autoanim/Scenes/AutoAnimsMain.tscn")

# AutoLoads
var AnimGenerator :AnimationGenerator
var Saver :AASavers

 # Ease-of-access reference to the plugin's GUI
var GUI :GenerateAnimsGUI


# Ease-of-access vars to the editor segments
var editor_interface := get_editor_interface()
var file_system_dock :FileSystemDock = get_editor_interface().get_file_system_dock()
var file_system :EditorFileSystem = get_editor_interface().get_resource_filesystem()

# Character list management references
var btn_CharacterList := preload("res://addons/Autoanim/Scenes/CharacterListButton.tscn")

# States management references
var btn_StateButton := preload("res://addons/Autoanim/Scenes/StateButton.tscn")
var lbl_DefaultGUILabel := preload("res://addons/Autoanim/Scenes/lbl_Default.tscn")

# Base Character Paths


# Character Vars
var character_name :String = ""
var char_filename :String = ""
var char_filepath :String = ""
var char_adr_path :String = ""
var base_character_path :String = "res://addons/Autoanim/CharacterBases/Base/BaseCharacter.tscn"
var base_character_script :String = "res://addons/Autoanim/Resources/Scripts/AABaseCharacter.gd"
var player_character_script :String = "res://addons/Autoanim/Resources/Scripts/AAPlayerCharacter.gd"


# State Vars
var selected_state :String = "" setget set_selected_state
var working_character :BaseCharacter


# Vars Tracker Reference
var vars_tracker_path := "res://addons/Autoanim/Resources/AutoAnimVarsTracker.tres"
var vars_tracker :VarsTracker

# Support Vars
var _first_setup = false



## SETUP FUNCTIONS FOR ADDON
func has_main_screen() -> bool:
	return true


func get_plugin_name() -> String:
	return "AutoAnim"


func get_plugin_icon() -> Texture:
	return editor_interface.get_base_control().get_icon("Animation", "EditorIcons")


func make_visible(visible: bool) -> void:
	if GUI:
		GUI.visible = visible


func _enter_tree() -> void:
	var dir :Directory = Directory.new()
	if !dir.file_exists(vars_tracker_path):
		var new_vars_tracker = VarsTracker.new()
		ResourceSaver.save(vars_tracker_path, new_vars_tracker)
		_first_setup = true
	GUI = main.instance()
	editor_interface.get_editor_viewport().add_child(GUI)
	make_visible(false)


func _ready() -> void:
	vars_tracker = load(vars_tracker_path)
	Saver = GUI.Saver
	Saver.vars_tracker = vars_tracker
	AnimGenerator = GUI.AnimGenerator
	AnimGenerator.vars_tracker = vars_tracker
	if _first_setup:
		_run_first_time_setup()
#		GUI.lbl_FTSCharacterScript.text = vars_tracker.BaseCharacterScript.substr(vars_tracker.BaseCharacterScript.rfind("/") + 1)
#		GUI.lbl_FTSPlayerScript.text = vars_tracker.PlayerCharacterScript.substr(vars_tracker.PlayerCharacterScript.rfind("/") + 1)
	_toggle_disabled_buttons_for_character()
	GUI.lbl_AssetDir.text = vars_tracker.AssetDirectory if vars_tracker.AssetDirectory != "" else "Please set a Spritesheet Directory"
	GUI.lbl_CharacterDir.text = vars_tracker.CharacterDirectory if vars_tracker.CharacterDirectory != "" else "Please set a Character Scenes Directory"
	self.selected_state = ""
	if !GUI.lbl_AssetDir.text.begins_with("res") or !GUI.lbl_CharacterDir.text.begins_with("res"):
		GUI.lbl_AddCharacterResults.text = "Please set both your Character and Asset directories..."
		GUI.lbl_AddCharacterResults.self_modulate = Color.aquamarine
	else:
		_reset_GUI_text(GUI.lbl_AddCharacterResults)
		_reset_GUI_text(GUI.lbl_CharacterCount, str(vars_tracker.CharacterList.size()))
	_setup_character_list()
	_verify_characters()
	_setup_default_values()
	
	print("AutoAnim Ready, ", self)
#	print(AnimGenerator, ", ", Saver)
	_connect_signals()


func _exit_tree() -> void:
	if GUI:
		GUI.queue_free()
	if working_character != null and is_instance_valid(working_character):
		working_character.queue_free()
	print("AutoAnim plugin removed, ", self)


func _connect_signals() -> void:
	# FIRST TIME SETUP CONNECTIONS
	GUI.btn_FTSAssetDirectory.connect("pressed", self, "_on_FTSAssetDirectory_pressed")
	GUI.btn_FTSCharacterDirectory.connect("pressed", self, "_on_FTSCharacterDirectory_pressed")
	GUI.btn_FTSCharacterScript.connect("pressed", self, "_on_FTSCharacterScript_pressed", [GUI.btn_FTSCharacterScript])
	GUI.btn_FTSPlayerScript.connect("pressed", self, "_on_FTSPlayerScript_pressed", [GUI.btn_FTSPlayerScript])
	GUI.btn_FTSSaveClose.connect("pressed", self, "_on_FTSSaveClose_pressed")
	GUI.btn_FTSDiscord.connect("pressed", self, "open_weblink_to", ["https://discord.gg/bmv4PUY3df"])
	GUI.btn_FTSYoutube.connect("pressed", self, "open_weblink_to", ["https://www.youtube.com/channel/UC2I6jA3l1V-xlxkvKA2gjRA"])
	GUI.btn_FTSDocs.connect("pressed", self, "open_weblink_to", ["https://thedoorworlds.github.io/AutoAnimGenerator/"])
	GUI.btn_FTSPatreon.connect("pressed", self, "open_weblink_to", ["https://www.patreon.com/TheDoorworlds"])
	
	
	# DIRECTORY SET CONNECTIONS
	GUI.btn_SetAssetDir.connect("pressed", self, "_on_SetAssetDirectory_pressed")
	GUI.btn_SetCharacterDir.connect("pressed", self, "_on_SetCharacterDirectory_pressed")
	GUI.btn_SetCharacterScript.connect("pressed", self, "_on_SetScript_pressed", [GUI.btn_SetCharacterScript])
	GUI.btn_SetPlayerScript.connect("pressed", self, "_on_SetScript_pressed", [GUI.btn_SetPlayerScript])
	GUI.ScriptPopup.connect("file_selected", self, "_on_Script_file_selected")
	GUI.CharacterDirectoryPopup.connect("dir_selected", self, "_on_CharacterDirectory_selected")
	GUI.AssetDirectoryPopup.connect("dir_selected", self, "_on_AssetDirectory_selected")
	
	
	# CHARACTER MANAGEMENT CONNECTIONS
	GUI.btn_AddCharacter.connect("pressed", self, "_on_AddCharacter_pressed")
	GUI.btn_PullCharacter.connect("pressed", self, "_on_PullCharacter_pressed")
	GUI.btn_GenerateAnimations.connect("pressed", self, "_on_GenerateAniamtions_pressed")
	GUI.btn_ClearAnimations.connect("pressed", self, "_on_ClearAnimations_pressed")
	GUI.btn_ResetStates.connect("pressed", self, "_on_ResetStates_pressed")
	GUI.btn_ResetStatetoDefault.connect("pressed", self, "_on_ResetStatetoDefault_pressed")
	GUI.btn_RemoveCharacter.connect("pressed", self, "_on_RemoveCharacter_pressed")
	GUI.btn_OpenCharacterScene.connect("pressed", self, "_on_OpenCharacterScene_pressed")
	GUI.btn_RefreshCharacterList.connect("pressed", self, "_on_RefreshCharacterList_pressed")
	GUI.btn_PullStates.connect("pressed", self, "_on_PullStates_pressed")
	GUI.btn_MakePlayer.connect("pressed", self, "_on_MakePlayer_pressed")
	GUI.line_CharacterName.connect("text_changed", self, "_on_CharacterNameLine_changed")
	for button in GUI.vbox_CharacterList.get_children():
		if !button.is_connected("toggled", self, "_on_CharacterListButton_toggled"):
			button.connect("toggled", self, "_on_CharacterListButton_toggled", [button])
	
	
	# EDIT DEFAULTS CONNECTIONS
	GUI.btn_OpenBaseCharacter.connect("pressed", self, "_on_OpenBaseCharacter_pressed")
	GUI.btn_EditDefaults.connect("pressed", self, "_on_EditDefaults_pressed")
	GUI.btn_DefaultsClose.connect("pressed", self, "_on_EditDefaultsInterface_closed")
	GUI.btn_DefaultOpenBaseCharacter.connect("pressed", self, "_on_OpenBaseCharacter_pressed")
	
	
	# EDIT STATE INTERFACE CONNECTIONS
	GUI.btn_EditState.connect("pressed", self, "_on_EditState_pressed")
	GUI.btn_ESSave.connect("pressed", self, "_on_ESSave_pressed")
	GUI.btn_ESSaveClose.connect("pressed", self, "_on_ESSaveClose_pressed")
	GUI.btn_Scale1x.connect("pressed", self, "_on_ScaleButton_pressed", [1])
	GUI.btn_Scale2x.connect("pressed", self, "_on_ScaleButton_pressed", [2])
	GUI.btn_Scale3x.connect("pressed", self, "_on_ScaleButton_pressed", [3])
	GUI.btn_ESGenerateAnims.connect("pressed", self, "_on_GenerateAnims_pressed")
	GUI.btn_ESChooseTexture.connect("pressed", self, "_on_ChooseTexture_pressed")
	GUI.btn_ESPullRefs.connect("pressed", self, "_on_ESPullRefs_pressed")
	GUI.cbox_ESLooping.connect("toggled", self, "_on_Looping_toggled")
	GUI.opt_ESPreviewAnimation.connect("item_selected", self, "_on_ESPreviewAnimation_item_selected")
	GUI.spin_ESSpriteHeight.connect("value_changed", self, "_on_ESSpriteSize_value_changed", [GUI.spin_ESSpriteHeight])
	GUI.spin_ESSpriteWidth.connect("value_changed", self, "_on_ESSpriteSize_value_changed", [GUI.spin_ESSpriteWidth])
	GUI.spin_ESAnimLength.connect("value_changed", self, "_on_ESAnimLength_value_changed")
	GUI.spin_ESAnimStep.connect("value_changed", self, "_on_ESAnimStep_value_changed")
	GUI.ChooseTextureDialogue.connect("file_selected", self, "_on_ChooseTextureDialog_file_selected")
	GUI.EditStateInterface.connect("popup_hide", self, "_on_EditStateInterface_popup_hide")
	
	
	# ANIMATION GENERATOR CONNECTIONS
	AnimGenerator.connect("character_not_added", self, "_on_AnimGenerator_character_not_added")
#	AnimGenerator.connect("animations_created", self, "_on_AnimationGenerator_animations_created")

	# OTHER CONNECTIONS
	GUI.btn_ResetAutoAnim.connect("pressed", self, "_on_ResetAutoAnim_pressed")


func _setup_character_list() -> void:
	if vars_tracker.CharacterList.size() > 0:
		for character in vars_tracker.CharacterList:
			var new_button := btn_CharacterList.instance()
			new_button.name = "btn_" + character.replace(" ", "")
			new_button.text = character
			if !new_button.is_connected("toggled", self, "_on_CharacterListButton_toggled"):
				new_button.connect("toggled", self, "_on_CharacterListButton_toggled", [new_button])
			GUI.vbox_CharacterList.add_child(new_button)


func _verify_characters() -> bool:
	var dir := Directory.new()
	if vars_tracker.CharacterDirectory:
		var char_directory :String = vars_tracker.CharacterDirectory
		for character in vars_tracker.CharacterList:
			if !dir.file_exists(char_directory.plus_file(character.replace(" ","") + ".tscn")):
				printerr("Character '%s' scene not found!  Please manually check your Character Directory!" % character)
				
				### Perhaps popup an interface to ask how the use wants to reconcile the data?
				return false
				
				
			if !dir.file_exists(char_directory.plus_file(character.replace(" ","") + "AnimationData.tres")):
				printerr("Character '%s' Animation Data not found!  Please manually check your Character Directory!")
				
				### Perhaps popup an interface to create the data file?
				return false
#	else:
#		printerr("Character Directory not yet set!  Please set in the AutoAnim interface.")
	print("All characters in Character List accounted for.")
	return true


#----------------------------------------------------------------------------------------------------------------------------------
## FIRST TIME SETUP FUNCTIONS
# Functions to support the first time setup of the addon per project.
func _on_FTSAssetDirectory_pressed() -> void:
	# Sets the default directory for assets
	GUI.AssetDirectoryPopup.dialog_text = "Please select the directory where you store your spritesheets"
	GUI.AssetDirectoryPopup.popup_centered(Vector2(500,500))
	yield(GUI.AssetDirectoryPopup, "dir_selected")
	GUI.lbl_FTSAssetDirectory.text = vars_tracker.AssetDirectory
	if GUI.lbl_FTSAssetDirectory.text and GUI.lbl_FTSCharacterDirectory.text:
		GUI.btn_FTSSaveClose.disabled = false


func _on_FTSCharacterDirectory_pressed() -> void:
	# Sets the default directory for character scenes
	GUI.CharacterDirectoryPopup.dialog_text = "Please select the directory where you store your Character Scenes"
	GUI.CharacterDirectoryPopup.popup_centered(Vector2(500,500))
	yield(GUI.CharacterDirectoryPopup, "dir_selected")
	GUI.lbl_FTSCharacterDirectory.text = vars_tracker.CharacterDirectory
	if GUI.lbl_FTSAssetDirectory.text and GUI.lbl_FTSCharacterDirectory.text:
		GUI.btn_FTSSaveClose.disabled = false


func _on_FTSSaveClose_pressed() -> void:
	vars_tracker.DefaultSpriteHeight = GUI.spin_FTSSpriteHeight.value
	vars_tracker.DefaultSpriteWidth  = GUI.spin_FTSSpriteWidth.value
	vars_tracker.DefaultDirectionSet = GUI.opt_FTSDirectionSet.selected
#	vars_tracker.BaseCharacterScript = GUI.lbl_FTSCharacterScript.text
#	vars_tracker.PlayerCharacterScript = GUI.lbl_FTSPlayerScript.text
	vars_tracker.DefaultAnimationLength = GUI.spin_FTSAnimLength.value
	vars_tracker.DefaultAnimationStep = GUI.spin_FTSAnimStep.value
	Saver.save_vars_tracker()
	_setup_default_values()
	GUI.FirstTimeSetupPopup.hide()

#----------------------------------------------------------------------------------------------------------------------------------
## GUI SET FUNCTIONS
# These functions will update the display of the GUI


func _reset_GUI_text(label :Label, new_text :String = "") -> void:
	# Resets text on the given label to the new_text and sets the modulate color to white
	label.text = new_text
	label.self_modulate = Color.white


func _refresh_states_buttons(states :Array = []) -> void:
	# Refreshes the states buttons in the state information panel
	
	# Create a new directory object to work with
	var dir = Directory.new()
	
	# Verify the filepath for the chraacter exists and is valid
	if char_filepath != "" and char_filename.is_valid_filename():
		# Check that the character's scene exists
		if dir.file_exists(char_filepath):
			# Remove any existing state buttons
			for child in GUI.grid_StatesButtonGrid.get_children():
				child.queue_free()
			
			# Make and connect signals for current state buttons
			for state in states:
				# Make an instance of the button
				var new_button := btn_StateButton.instance()
				
				# Set the button's text
				new_button.text = str(state)
				
				# Connect the button's 'pressed' signal to the corresponding function, passing the state as an extra argument
				new_button.connect("pressed", self, "_on_StateButton_pressed", [state])
				
				# Add the button as a child of the states button grid
				GUI.grid_StatesButtonGrid.add_child(new_button)
		else:
			# If the file doesn't exist, simply remove all states buttons
			for child in GUI.grid_StatesButtonGrid.get_children():
				child.queue_free()
				
	# Toggle the available buttons
	_toggle_disabled_buttons_for_character()


func _set_direction_set_text(value :int) -> String:
	# Sets the direction set text to the given value
	return GUI.opt_DefaultDirectionSet.get_item_text(value)


func _set_default_animations_labels() -> void:
	# Sets up the display of the default animations
	var base_character :BaseCharacter = load(base_character_path).instance()
	
	# If any exist, remove them so there are no duplicates
	for child in GUI.grid_DefaultAnimations.get_children():
		child.queue_free()
	
	# Get states from the Base Character and create a label as a child of the Default Animations grid for each state
	for state in _get_states_from_character(base_character):
		var animation_label :Label = lbl_DefaultGUILabel.instance()
		animation_label.text = state
		GUI.grid_DefaultAnimations.add_child(animation_label)


func _reset_GUI_to_default() -> void:
	# Resets the GUI labels to default values
	
	# Iterate over all children of teh main GUI
	for child in GUI.get_children():
		
		# Check if the child is a Label
		if child is Label:
			
			# Make sure ti's a label that contains dynamic information and is not a header
			if child.name.begins_with("lbl_"):
				
				# Ignore the Directory labels
				if !child.name.ends_with("Directory"):
					
					#Reset the labels
					_reset_GUI_text(child)
					
	# Reset the remaining labels to the appropriate settings
	_reset_GUI_text(GUI.lbl_CharacterOutput)
	_reset_GUI_text(GUI.lbl_CharacterInfoHeader, "Character Info for: ")
	
	# Clear the state buttons from the States Grid
	for child in GUI.grid_StatesButtonGrid.get_children():
		child.queue_free()
	
	# Reset the header for the Info panel
	_reset_GUI_text(GUI.lbl_StateInfoHeader, "Info for state:")


func _toggle_disabled_buttons_for_character() -> void:
	# Toggles GUI button states based on provided text in the Character Line Edit
	if vars_tracker.CharacterList.has(character_name):
		# If the VarsTracker has the given character, Do not allow 'Add Character' to be pressed and toggle other relevant buttons to Enabled.
		GUI.btn_AddCharacter.disabled = true
		GUI.btn_PullCharacter.disabled = false
		GUI.btn_RemoveCharacter.disabled = false
		GUI.btn_OpenCharacterScene.disabled = false
		GUI.btn_PullStates.disabled = false
		GUI.btn_ClearAnimations.disabled = false
		GUI.btn_MakePlayer.disabled = false
	else:
		# If not, Enable the 'Add Character' button only.
		GUI.btn_AddCharacter.disabled = false
		GUI.btn_PullCharacter.disabled = true
		GUI.btn_RemoveCharacter.disabled = true
		GUI.btn_OpenCharacterScene.disabled = true
		GUI.btn_PullStates.disabled = true
		GUI.btn_ClearAnimations.disabled = true
		GUI.btn_MakePlayer.disabled = true
	
	# Only allow resetting of states on an existing character that's successfully loaded into memory.
	if !working_character:
		GUI.btn_ResetStates.disabled = true
	else:
		GUI.btn_ResetStates.disabled = false
		var wr = weakref(working_character)
		
		# Check for Player Character Script -- NOT FUNCTIONAL AT THIS TIME.
		if wr.get_ref():
			if working_character.get_script() == load(player_character_script):
				GUI.btn_MakePlayer.disabled = true


func _handle_loaded_refs() -> void:
	# Handles the loading and unloading of resources being referenced by the addon
	
	# We need to use a WeakRef to ensure that the character is unloaded from memory to avoid leaks and make sure we're working with an up-to-date and correct character instance
	if working_character != null and is_instance_valid(working_character):
#			print("Freeing working_character %s..." % working_character)
		var wr := weakref(working_character)
		working_character.free()
		if wr.get_ref():
			working_character.free()
			if wr.get_ref():
				printerr("   Unable to free character %s." % working_character)
				return
	
	# Check is the filename is valid and make sure that the varsTracker Character list is accounting for the name.
	if char_filename.is_valid_filename() and vars_tracker.CharacterList.has(character_name):
		working_character = load(char_filepath).instance()
#		print("Loading working_character %s..." % working_character.character_name)
		
		# Print statements to send the status to the Output panel.  This is not necessary, but helpful to see that ti's working properly.
		if working_character == null or !is_instance_valid(working_character):
			printerr("Failed to load working_character instance.")
#			
#		else:
#			print("   Sucessfully loaded instance of %s!" % working_character)
	
	if !working_character:
		# This print statement will show an error if the character does not successfully load
		printerr("working_character load failed.")


func _clear_state_info_panel() -> void:
	# Clears the State Info section to display default blank values.  Useful when switching working charactcers.
	for label in GUI.state_info_labels:
		label.text = ""
	GUI.trect_InfoStateTexture.texture = null
	GUI.lbl_InfoTexturePath.text = ""
	GUI.lbl_StateInfoHeader.text ="Info for state:"
	for child in GUI.grid_StatesButtonGrid.get_children():
		child.queue_free()


func _refresh_state_info_panel() -> void:
	# Refreshes the state info panel to show the information relevant to the current Working Character and Selected State.
	
	# Make sure the selected_state is not empty.
	if selected_state != "":
		# Pull the corresponding info from the Working Character's Animation Data Resource (ADR).
		GUI.lbl_InfoAnimLength.text = str(working_character.animation_data.states_details_map[selected_state]["anim_length"])
		GUI.lbl_InfoAnimStep.text = str(working_character.animation_data.states_details_map[selected_state]["anim_step"])
		GUI.lbl_InfoSpriteSize.text = "%s px by %s px" % [
			working_character.animation_data.states_details_map[selected_state]["sprite_width"],
			working_character.animation_data.states_details_map[selected_state]["sprite_height"]
			]
		# Check if the ADR has a texture assigned, and if so load it as a preview
		if working_character.animation_data.states_details_map[selected_state]["texture"] != "":
			GUI.trect_InfoStateTexture.texture = load(working_character.animation_data.states_details_map[selected_state]["texture"])
	
	# If the selected_state is empty, clear the info panel and pull a fresh set of state buttons
	elif working_character != null and is_instance_valid(working_character):
		_clear_state_info_panel()
		_refresh_states_buttons(_get_states_from_character(working_character))
		
	else:
	# If no charatcer is selected and no state is selected, just clear it all out
		_clear_state_info_panel()



#------------------------------------------------------------------------------------------------------------------
## STATE MANAGEMENT FUNCTIONS
# These functions manage the states on the working character

func _get_states_from_character(character :BaseCharacter) -> Array:
	# Gets a list of the states from the given character
	
	# Create an empty array that we will return at the end
	var states_array := []
	
	# Assert statement to ensure that the character was passed correctly into the function
	assert(character, "Character not found!")
	
	# Get a reference to the animation tree on the character
	var anim_tree :AnimationTree = character.get_node("AnimationTree")
	
	# Get a reference to the state machine on the character
	var state_machine :AnimationNodeStateMachine = anim_tree.tree_root
	
	# Iterate over the entire property list (which is a Dictionary of Dictionaries) of the state machine to find the nodes that we need
	for prop_dict in state_machine.get_property_list():
		# Get the name of the property from
		var prop_name = prop_dict.get('name')
		# If that name contains '/node', reformat the string to display as just the state's name
		if prop_name.find('/node') > -1:
			var state :String = str(prop_name).replace("states/", "").replace("/node", "")
			# Append the formatted name to the array
			states_array.append(state)
	
	# Return the array for use in other functions
	return states_array


func _reset_states_on_character_to_default() -> bool:
	# Resets the states on the given character to match the Base Character
	
	# Pull a ref to the state machine of the Working Character
	var state_machine :AnimationNodeStateMachine = working_character.get_node("AnimationTree").tree_root
	
	# Pull an instance of the Base Character to copy from
	var base_character_instance :BaseCharacter = load(base_character_path).instance()
	
	# Get the Base Character's states
	var base_char_states :Array = _get_states_from_character(base_character_instance)
	
	# Get the Working Character's states
	var working_states :Array = _get_states_from_character(working_character)
	
	# Remove all of the states from the working character
	for state in working_states:
		# Each 'state' will be a string obtained from the _get_states_from_character() function
		state_machine.remove_node(state)
		
	# Set up the initial position for the newly placed nodes to occupy
	var node_position := Vector2(0,0)
	
	# Iterate over the states in the Base Character and create new nodes with the same names on the Working Character
	for state in base_char_states:
		# Add the node with the state as the name, a new BlendSpace2D as the type, at the node position
		state_machine.add_node(state, AnimationNodeBlendSpace2D.new(), node_position)
		# Increment the node's position so that there is no overlap in the interface when editing by hand
		node_position.y += 50
		# To avoid a long vertical list of nodes if there are many states, we move right by 200 and reset the y value if more than 4 states are placed in a column (x value)
		if node_position.y >= 150:
			node_position.y = 0
			node_position.x += 200
	
	# Iterate over a fresh pull of the working character's states to verify the correct states are present
	for state in _get_states_from_character(working_character):
		# Make sure the states on the Working Character are also on the Base Character
		if !base_char_states.has(state):
			# If the state doesnt' exist on the Base Character, the fucntion returns false as the removal of all previous nodes was unsuccessful
			# We also free the reference to the Base Character to mitigate memory leaks
			base_character_instance.queue_free()
			return false
	
	# Free the loaded reference to the Base Character to mitigate memory leaks
	base_character_instance.queue_free()
	# Handle the references to load a fresh copy of the Working Character now that the states have been reset
	_handle_loaded_refs()
	# Return true upon successful reset
	return true



#------------------------------------------------------------------------------------------------------------------
## CHARACTER DATA FUNCTIONS
# These functions handle the characters data

func pull_character_data(character_name :String) -> Dictionary:
	# Pulls the data from the Animation Data of the given character and separates out the relevant variables
	
	# Create a Dictionary which we will return later
	var character_data := {}
	
	# Create an empty Arry which will hold the ADR variables we need
	var character_adr_vars :Array
	
	# If the VarsTracker Character List doesn't have the character name, return an empty Dictionary
	if !vars_tracker.CharacterList.has(character_name):
		return {}
	
	# Pull the full property list
	var character_plist :Array = working_character.animation_data.get_property_list()
	
	# Check the property list for custom variables and add them to the return Dictionary (8199 is the "usage" value for custom variables)
	for property in character_plist:
		for key in property.keys():
			if key == "usage":
				if property["usage"] == 8199:
#					print("Property 'usage' value == 8199 ")
					character_adr_vars.append(property["name"])
#					print("Added %s to character_adr_vars." % property["name"], "\n")
#				else:
#					print("Usage key was not 8199", "\n")
#			else:
#				print("Key '%s' was not 'usage'." % key)
	
	# Assigns the variable's value to the appropriate dictionary key for parsing
	for variable in character_adr_vars:
		for index in character_adr_vars.size():
			character_data[variable] = working_character.animation_data.get_property_value(variable)
#	print("Character Data: ", character_data)
	return character_data


func parse_character_data_for_output(character_data :Dictionary) -> String:
	# Returns a string of parsed-out information properly formatted for display in the info box.
	# This function has been separated out for EOA
	
	# Create our initial variable which will hold the return string
	var output_text :String = ""
	
	# Iterate over all items in the provided character data
	for item in character_data:
		# Get the states_details_map
		if item == "states_details_map":
			# Iterate over the keys of the states_details_map (which are the states)
			for state in character_data[item]:
				# Make the state the initial string and add some formatting
				output_text += str(state) + ":\n"
				# Iterate over each detail in the state and add it on a separate lien to the string
				for detail in character_data[item][state]:
					output_text += "   " + str(detail) + ": " + str(character_data[item][state][detail]) + "\n"
		else:
			# For the items that are not part of the states_details_map, add it to the string on its own line.
			output_text += str(item) + ": " + str(character_data[item]) + "\n"
	
	# Return the output text
	return output_text


func _show_character_data() -> void:
	# Sets up the GUI to show the information relevant to the character in the Name line
	_refresh_states_buttons(_get_states_from_character(working_character))
	
	# Set the Character Info header to contain the Working Character's name
	GUI.lbl_CharacterInfoHeader.text = "Character Info for: " + working_character.character_name
	# Set the Character Output pane to contain the details of the character
	GUI.lbl_CharacterOutput.text = parse_character_data_for_output(pull_character_data(working_character.character_name))


func _on_PullCharacter_pressed() -> void:
	# Pulls the character data manually
	
	# Reset the GUI labels first
	_reset_GUI_to_default()
	
	# Pupulate fresh data
	_show_character_data()


#------------------------------------------------------------------------------------------------------------------
## CHARACTER MANAGEMENT FUNCTIONS
# These functions manage the characer list

func add_character() -> bool:
	# Sets up and saves out a new scene for a new character
	# Returns 'true' if the character is successfully created, 'false' if not
	
	# First, check that the filename is valid
	if char_filename.is_valid_filename():
		# Make sure that filename is not empty
		if character_name != null:
			print("Adding character: ", char_filename)
			
			# Call the Animation Generator to set up a new character
			var new_character = AnimGenerator.setup_new_character(character_name)
			
			#Ensure the new character was set up properly before continuing
			if new_character:
				# Call the Saver to save out the new file and verify that it saves successfully.
				if Saver.pack_and_save_character(new_character):
					# Refreshe the inspector interface to ensure the new files are shown properly
					editor_interface.get_inspector().refresh()
					
					# Make sure that teh VarsTracker Character List does not already have the given name and append it
					if !vars_tracker.CharacterList.has(character_name):
						vars_tracker.CharacterList.append(character_name)
						# Save the VarsTracker to make sure the change persists
						Saver.save_vars_tracker()
					
					# Update the interface to give the user feedback on the success of the character creation
					GUI.lbl_AddCharacterResults.text = "Character '%s' Successfully Added!" % character_name
					GUI.lbl_AddCharacterResults.self_modulate = Color.green
					# Update the visible running total of characters
					GUI.lbl_CharacterCount.text = str(vars_tracker.CharacterList.size())
					# Toggle the available buttons
					_toggle_disabled_buttons_for_character()
					
					# Make a new button for the Character List VBox
					var new_button := btn_CharacterList.instance()
					new_button.name = "btn_" + char_filename
					new_button.text = character_name
					# Connect the new button to the associated function, passing itself as an argument
					new_button.connect("toggled", self, "_on_CharacterListButton_toggled", [new_button])
					# Add the button as a child of the Character List VBox
					GUI.vbox_CharacterList.add_child(new_button)
					
					# Set up the Animation Data Resource for the new character
					create_new_adr(new_character)
					
					# Set the node references -- THIS IS BUGGY. WORKING ON FIXING
					new_character.animPlayer = new_character.get_node("CharacterSprite/SpriteAnimationPlayer")
					new_character.animTree = new_character.get_node("AnimationTree")
					# Ensure that the animation tree's root is local to scene to make sure that changes only affect the given character
#					new_character.animTree.tree_root = load("res://addons/Autoanim/CharacterBases/Base/AAAnimationTreeRoot.tres").duplicate()
#					new_character.animTree.tree_root.resource_local_to_scene = true
#					new_character.animTree.set(
#						"parameters/StateMachine/playback",
#						load("res://addons/Autoanim/CharacterBases/Base/AAStateMachinePlayback.tres").duplicate()
#						)
#					new_character.animTree.get("parameters/StateMachine/playback").resource_local_to_scene = true
					
					#Save the character after teh additional charges have been made
					if _save_character(new_character):
						
						# This loop is for debugging - it will list all properties of the Animation Tree in a legible format
#						var character_anim_tree_data :Array= new_character.get_node("AnimationTree").get_property_list()
#						for property in character_anim_tree_data:
#							print("Property: ", property)
#							for key in property:
#								print(key, " = ", property[key])
								
						# If the save is successful, return 'true'.
						return true
				
				# The following lines are all just error catching prnt statements for the output panel
				else:
					printerr("Did not successfully add '%s', failed to pack and save..." % character_name)
			else:
				printerr("Did not successfully add '%s', failed to instance new character in animation generator" % character_name)
	else:
		printerr("Did not successfully add '%s', invalid filename." % character_name)
	
	# Return false if the creation was unsuccessful
	return false


func create_inherited_scene(inherits :PackedScene, root_name := "Scene") -> PackedScene:
	# Creates an inherited scene -- NOT FUNCTIONING PROPERLY AT THIS TIME
	var scene := PackedScene.new()
	scene._bundled = {"base_scene": 0, "conn_count": 0, "conns": [], "editable_instances": [], "names": [root_name], "node_count": 1, "node_paths": [], "nodes": [-1, -1, 2147483647, 0, -1, 0, 0], "variants": [inherits], "version": 2}
	return scene


func remove_character(character_name :String) -> bool:
	# Returns `true` when a character has been successfully removed, `false` when removal fails.
	
	# Create a new Directory object to work with
	var dir :Directory = Directory.new()
	
	# Pops up a confirmation window to allow the user a chance to back out of the deletion process if accidentally clicked
	GUI.ConfirmationDialoguePopup.dialog_text = "Delete character '%s'?" % character_name
	# Pulls the size of the editor interface to use for choosing popup size
	var editor_viewport_rect = editor_interface.get_viewport().get_visible_rect()
	GUI.ConfirmationDialoguePopup.popup_centered(Vector2( editor_viewport_rect.size.x / 5, editor_viewport_rect.size.y /5 ))
	# Wait until the user confirms the choice
	yield(GUI.ConfirmationDialoguePopup, "confirmed")
	
	# Use a WeakRef to ensure the character has been freed to mitigate memory leaks
	var wr = weakref(working_character)
	if wr.get_ref():
		wr.get_ref().queue_free()
	
	# Move the Directory object to the Character Directory
	dir.change_dir(vars_tracker.CharacterDirectory)
#	print(" Checking for ", char_filepath)
	# Check that the character's file exists
	if dir.file_exists(char_filepath):
#		print("File %s found.  Attemping removal..." % char_filepath)
		# Remove the file
		dir.remove(char_filepath)
		# Run a scan on the file system to update the interface with the subtraction of the character file
		file_system.scan()
		# Refresh the inspector to reflect the changes
		editor_interface.get_inspector().refresh()
		
		# Check that the character's scene file has been successfully removed
		if !dir.file_exists(char_filepath):
#			print("   Successfully removed %s." % char_filepath)
			# Then check the ADR path to see if the ADR is present
			if ResourceLoader.exists(char_adr_path):
				# If it is, blow out the path to make sure the data will not stay cached...
				_blow_out_adr_path(char_adr_path)
#				print("File %s found.  Attemping removal..." % char_adr_path)
				# ...and remove the file
				dir.remove(char_adr_path)
				
				# Check that the removal was successful
				if !dir.file_exists(char_adr_path):
#					print("   Successfully removed %s." % char_adr_path)
					# Remove the character's name fron the VarsTracker Character List
					vars_tracker.CharacterList.remove(vars_tracker.CharacterList.find(character_name))
					# Verify the removal
					if !vars_tracker.CharacterList.has(character_name):
						# Print a success message
						print("SUCCESSFULLY REMOVED ", character_name)
						# Refresh the interface to reflect changes
						editor_interface.get_inspector().refresh()

						# Get a reefnce to the associated Character List button
						var button := GUI.vbox_CharacterList.get_node("btn_%s" % char_filename)
						# Remove that button
						GUI.vbox_CharacterList.remove_child(button)
						# Free the instance
						button.queue_free()
						# Toggle the available buttons
						_toggle_disabled_buttons_for_character()
						# Save the VarsTracker with the updated Character list
						Saver.save_vars_tracker()
						# Reload the character references to ensure that the deleted character is not held in memory
						_handle_loaded_refs()
						# Set teh selected state back to empty
						self.selected_state = ""
						# Reset the state info labels
						for label in GUI.state_info_labels:
							label.text = ""
						# Return true upon successful deletion
						return true
				# Print statements for troubleshooting a failed removal
				else:
					print("File not removed: ", char_adr_path)
			else:
				print(char_adr_path, " not found.")
		else:
			print("File not removed: ", char_filepath)
	else:
		print("Did not find ", char_filepath)
	print("Failed to remove ", character_name)
	
	# Toggle available buttons and return false upon unsuccessful removal of the character
	_toggle_disabled_buttons_for_character()
	return false


func create_new_adr(character :BaseCharacter) -> bool:
	# Sets up and populates a fresh Animation Data Resource for the given character
	
	# Create a new ADR and ensure there is no cached data for it
	var animation_data := _blow_out_adr_path(char_adr_path)
	
	# Set the character's animation data to be the new ADR
	character.animation_data = animation_data
	# Make it local to scene to make sure changes stay on just the given character
	character.animation_data.resource_local_to_scene = true
	# Name the resource to identify it for the character
	animation_data.resource_name = character_name.replace(" ", "") + "AnimationData"
	# Populate the ADR's variables with the appropriate information from the character
	animation_data.character_name = character_name
	animation_data.char_file_name = character_name.replace(" ","") + ".tscn"
	
	# Clear out any existing direction set if one exists
	animation_data.directions.clear()
	
	# Copy the Default directions fron the Vars Tracker to the new ADR
	for direction in vars_tracker.DefaultDirections:
		animation_data.directions.append(vars_tracker.Directions.keys()[direction].capitalize())
	
	# Set up a default states_details_map key for each state on the character
	animation_data.states = _get_states_from_character(character)
	for state in animation_data.states:
		animation_data.states_details_map[state] = {
			"anim_step" : vars_tracker.DefaultAnimationStep,
			"anim_length" : vars_tracker.DefaultAnimationLength,
			"texture" : "",
			"vframes" : 0,
			"hframes" : 0,
			"looping" : false,
			"frames" : 0,
			"frames_on_texture" : [],
			"sprite_width" : vars_tracker.DefaultSpriteWidth,
			"sprite_height" : vars_tracker.DefaultSpriteHeight
		}
	# Save the ADR and verify that it saves correctly
	if !Saver.save_character_adr(animation_data):
		# Print an error and return false if the save is unsuccessful
		printerr("New ADR not successfully created!")
		return false
	
	# Refresh the interface to reflect the changes
	editor_interface.get_resource_filesystem().scan()
	
	# Check that the file now exists in the fileystem
	return true


func _on_AddCharacter_pressed() -> void:
	# Receives the  'Add Character' button press signal 
	
	# Reset the GUI text
	_reset_GUI_text(GUI.lbl_AddCharacterResults)
	
	# Add the character, and reload upon success
	if add_character():
		_handle_loaded_refs()
		print("Character successfully added: ", working_character.character_name)
		# Show the new character's data
		_show_character_data()
		
		
	else:
		# If adding the characcter fails, display error text
		GUI.lbl_AddCharacterResults.text = "Cannot add character.  See Output panel for details."
		GUI.lbl_AddCharacterResults.self_modulate = Color.red


func _on_RemoveCharacter_pressed() -> void:
	# Receives teh 'Remove Character' button press signal
	if remove_character(character_name):
		# Upon successful removal of the character, wait for confirmation and then reset the GUI labels
		yield(GUI.ConfirmationDialoguePopup, "confirmed")
		_reset_GUI_to_default()
		GUI.lbl_AddCharacterResults.text = "%s successfully removed." % character_name
		GUI.lbl_CharacterCount.text = str(vars_tracker.CharacterList.size())
		GUI.lbl_AddCharacterResults.self_modulate = Color.green
		GUI.line_CharacterName.text = ""
		# manually emit the Character Name Line Edit's text_changed signal with an empty String
		GUI.line_CharacterName.emit_signal("text_changed", "")
	else:
		# If removal is unsuccessful, display a failure message
		GUI.lbl_AddCharacterResults.text = "Failed to remove %s" % character_name
		GUI.lbl_AddCharacterResults.self_modulate = Color.red


func _on_SetScript_pressed(which :Button) -> void:
	# Function to set the character scripts -- NOT FUNCTIONAL AT THIS TIME
	if which == GUI.btn_SetCharacterScript:
		GUI.ScriptPopup.dialog_text = "Choose a script for non-player characters (NPCs)..."
	elif which == GUI.btn_SetPlayerScript:
		GUI.ScriptPopup.dialog_text = "Choose a script for the player character..."
	else:
		printerr("Error with script choice popup...")
	
	GUI.ScriptPopup.popup_centered(Vector2(
			editor_interface.get_viewport().get_visible_rect().size.x / 3,
			editor_interface.get_viewport().get_visible_rect().size.y / 3
		))


func _on_Script_file_selected(path :String) -> void:
	# Sets the character script and related GUI labels upon seletio of a script -- NOT FUNCTIONAL AT THIS TIME
	
	# Set the Base Character script to be used
	if GUI.ScriptPopup.dialog_text.ends_with("(NPCs)..."):
		GUI.lbl_CharacterScript.text = path.substr(path.rfind("/") + 1)
		vars_tracker.BaseCharacterScript = path
		Saver.save_vars_tracker()
		
	# Set the Player script to be used
	elif GUI.ScriptPopup.dialog_text.ends_with("character..."):
		GUI.lbl_PlayerScript.text = path.substr(path.rfind("/") + 1)
		vars_tracker.PlayerCharacterScript = path
		Saver.save_vars_tracker()


func _on_MakePlayer_pressed() -> void:
	# Takes the currently referenced character and applies the Player script - NOT FUNCTIONAL AT THIS TIME
#	print("Starting script: ", working_character.get_script())
	working_character.set_script(load(vars_tracker.PlayerCharacterScript))
	
#	print("New script: ", working_character.get_script())
#	Saver.pack_and_save_character(working_character)
#	working_character.animation_data = working_adr
	if Saver.pack_and_save_character(working_character):
		_handle_loaded_refs()
	if working_character.get_script() != load(player_character_script):
		printerr("Unable to save character with Player script...")
		return
#	print("Script after save and handle: ", working_character.get_script())
	_toggle_disabled_buttons_for_character()


#------------------------------------------------------------------------------------------------------------------
## SIGNAL RECEIVERS
# These functions receive signals not associated with other major functionality

func _on_CharacterListButton_toggled(_button_pressed :bool, toggled_button :Button) -> void:
	# Receives the character list button toggle signals
	
	# Get the text of the button which emitted the signal and set the Character Name Line Edit to match it
	GUI.line_CharacterName.text = toggled_button.text
	# Manually emit the text_changed signal to trigger appropriate actions
	GUI.line_CharacterName.emit_signal("text_changed", toggled_button.text)
	# Show the selected character's data
	_show_character_data()
	_refresh_state_info_panel()
	# Toggle available buttons
	_toggle_disabled_buttons_for_character()
	# Set the selecte state to empty so that the user does not see information from the previous character's state
	self.selected_state = ""


func _on_RefreshCharacterList_pressed() -> void:
	# Used to manually refresh teh character list if a discrepency occurs
	
	# Remove all Character List buttons
	for child in GUI.vbox_CharacterList.get_children():
		child.queue_free()
	
	# Freshly set up the Character List
	_setup_character_list()
	# Update the Character Count label
	GUI.lbl_CharacterCount.text = str(vars_tracker.CharacterList.size())


func _on_AnimGenerator_character_exists() -> void:
	# Updates the GUI when the Animation Generator finds that the character already eixists when trying to create a new character/
	# This should never actually be called, it's just an error catcher
	GUI.lbl_AddCharacterResults.self_modulate = Color.green
	GUI.lbl_AddCharacterResults.text = "Character already exists!"


func _on_SetCharacterDirectory_pressed() -> void:
	# Pops up a Diretory Selector to choose a Character Directory
	# Set the dialog text on the popup
	GUI.CharacterDirectoryPopup.dialog_text = "Please select the directory where you store your Character Scenes"
	GUI.CharacterDirectoryPopup.popup_centered(Vector2(500,500))


func _on_CharacterDirectory_selected(path :String) -> void:
	# Takes the chosen path and assigns it as the Character Directory
	
	# Set the GUI label to reflect the selected path
	GUI.lbl_CharacterDir.text = path
	# Set the Character Directory in the VarsTracker
	vars_tracker.CharacterDirectory = path
	# Save the Vars Tracker
	Saver.save_vars_tracker()
	
	# Run a check to see if both of the required Directories are filled out, and set the related GUI labels accordingly
	if !GUI.lbl_AssetDir.text.begins_with("res") or !GUI.lbl_CharacterDir.text.begins_with("res"):
		GUI.lbl_AddCharacterResults.text = "Please set both your Character and Asset directories..."
		GUI.lbl_AddCharacterResults.self_modulate = Color.aquamarine
	else:
		# If both Directories aer filled, reset the GUI to default
		_reset_GUI_text(GUI.lbl_AddCharacterResults)


func _on_SetAssetDirectory_pressed() -> void:
	# Pops up a Diretory Selector to choose an Asset Directory
	# Set the dialog text on the popup
	GUI.AssetDirectoryPopup.dialog_text = "Please select the directory where you store your spritesheets"
	GUI.AssetDirectoryPopup.popup_centered(Vector2(500,500))


func _on_AssetDirectory_selected(path :String) -> void:
	# Takes the chosen path and assigns it as the Asset Directory
	
	# Set the GUI label to reflect the selected path
	GUI.lbl_AssetDir.text = path
	# Set the Asset Directory in the VarsTracker
	vars_tracker.AssetDirectory = path
	# Save the VarsTracker
	Saver.save_vars_tracker()
	
	# Run a check to see if both of the required Directories are filled out, and set the related GUI labels accordingly
	if !GUI.lbl_AssetDir.text.begins_with("res") or !GUI.lbl_CharacterDir.text.begins_with("res"):
		GUI.lbl_AddCharacterResults.text = "Please set both your Character and Asset directories..."
		GUI.lbl_AddCharacterResults.self_modulate = Color.aquamarine
	else:
		# If both Directories aer filled, reset the GUI to default
		_reset_GUI_text(GUI.lbl_AddCharacterResults)


func _on_CharacterNameLine_changed(new_text :String) -> void:
	# Dyamically updates the variables for the function of this plugin
	character_name = new_text
	# Formats the character filename based on the new text
	char_filename = new_text.replace(" " ,"")
	# Sets the full filepath based on the new text
	char_filepath = vars_tracker.CharacterDirectory.plus_file(char_filename + ".tscn")
	# Sets the Animation Data Resource's file path based on the new text
	char_adr_path = vars_tracker.CharacterDirectory.plus_file(char_filename + "AnimationData.tres")
	
	# If the new text is empty, reset the GUI buttons appropriately
	if new_text == "":
#		print("Character not found.")
		GUI.btn_AddCharacter.disabled = true
		GUI.btn_PullCharacter.disabled = true
		GUI.btn_RemoveCharacter.disabled = true
		GUI.btn_PullStates.disabled = true
		GUI.btn_ResetStates.disabled = true
		GUI.btn_ClearAnimations.disabled = true
		GUI.btn_OpenCharacterScene.disabled = true
		_clear_state_info_panel()
		return
	
	# If either of the Directories is empty, reset teh GUI buttons and labels appropriately
	if !GUI.lbl_AssetDir.text.begins_with("res") or !GUI.lbl_CharacterDir.text.begins_with("res"):
		printerr("Directories not selected...")
		GUI.btn_AddCharacter.disabled = true
		GUI.btn_PullCharacter.disabled = true
		GUI.btn_RemoveCharacter.disabled = true
		GUI.btn_PullStates.disabled = true
		GUI.btn_ResetStates.disabled = true
		GUI.btn_ClearAnimations.disabled = true
		# Set the GUI Results Label to provide information to the user
		GUI.lbl_AddCharacterResults.text = "Please set both your Character and Asset directories..."
		GUI.lbl_AddCharacterResults.self_modulate = Color.aquamarine
		GUI.btn_OpenCharacterScene.disabled = true
		# Clear out any state informtaion
		_clear_state_info_panel()
		return
	
	# Reset GUI labels apropriately
	_reset_GUI_text(GUI.lbl_CharacterOutput)
	_reset_GUI_text(GUI.lbl_CharacterInfoHeader, "Character Info for: ")
	
	# Set all state info labels correctly
	for label in GUI.state_info_labels:
		label.text = ""
	# Remove any existing texture from the Info Panel
	GUI.trect_InfoStateTexture.texture = null
	
	# Set the Selected State to empty
	self.selected_state = ""
	
	# Check if the Vars Tracker ahs the given character.
	if vars_tracker.CharacterList.has(new_text):
		# If it does, load a reference to the character and set up the state buttons
		_handle_loaded_refs()
		_refresh_states_buttons(_get_states_from_character(working_character))
	else:
		# If not, clear everything out
		_refresh_states_buttons()
	
	# Toggle available buttons
	_toggle_disabled_buttons_for_character()


func _on_OpenCharacterScene_pressed() -> void:
	# Opens the given character's scene in the eitor
	editor_interface.open_scene_from_path(char_filepath)


#func _on_OpenBaseCharacter_pressed() -> void:
#	editor_interface.open_scene_from_path(base_character_path)


func _on_AnimGenerator_character_not_added(error_code :int, originating_object) -> void:
	printerr("ERROR on %s: %s" % [originating_object, error_code])


func _on_PullStates_pressed() -> void:
	# Manually pulls the states if an error occurs
	
	# Ensure that the character filepath is valid...
	if char_filepath != "" and char_filename.is_valid_filename():
		# ... and refresh the states buttons if it is
		_refresh_states_buttons(_get_states_from_character(working_character))


#------------------------------------------------------------------------------------------------------------------
## EDIT DEFAULTS FUNCTIONS
# These functions manage teh defaults for new characters and animations

func _on_OpenBaseCharacter_pressed() -> void:
	match working_character.direction_set:
		vars_tracker.DirectionSets.FDTD:
			editor_interface.open_scene_from_path(AnimGenerator.FDTDCharacterBasePath)
		vars_tracker.DirectionSets.FDIS:
			editor_interface.open_scene_from_path(AnimGenerator.FDISCharacterBasePath)
		vars_tracker.DirectionSets.EDTD:
			editor_interface.open_scene_from_path(AnimGenerator.EDTDCharacterBasePath)
		vars_tracker.DirectionSets.TDPF:
			editor_interface.open_scene_from_path(AnimGenerator.TDPFCharacterBasePath)
		_:
			printerr("Invalid Direction Set.")


func _on_EditDefaults_pressed() -> void:
	# Opens the Edit Defaults nterface and sets the initial values based on the VarsTracker
	GUI.spin_DefaultSpriteHeight.value = vars_tracker.DefaultSpriteHeight
	GUI.spin_DefaultSpriteWidth.value = vars_tracker.DefaultSpriteWidth
	GUI.opt_DefaultDirectionSet.selected = vars_tracker.DefaultDirectionSet
	GUI.spin_DefaultAnimLength.value = vars_tracker.DefaultAnimationLength
	GUI.spin_DefaultAnimStep.value = vars_tracker.DefaultAnimationStep
	GUI.EditDefaultsInterface.popup()


func _refresh_default_values() -> void:
	# Refreshes the Default Values panel
	_set_default_animations_labels()
	_set_default_directions_labels()
	GUI.lbl_DefaultDirectionSet.text = _set_direction_set_text(vars_tracker.DefaultDirectionSet)
	GUI.lbl_DefaultLength.text = str(vars_tracker.DefaultAnimationLength)
	GUI.lbl_DefaultSpriteSize.text = "%spx by %spx" % [str(vars_tracker.DefaultSpriteHeight), str(vars_tracker.DefaultSpriteWidth)]
	GUI.lbl_DefaultStep.text = str(vars_tracker.DefaultAnimationStep)


func _on_EditDefaultsInterface_closed() -> void:
	# Executes upon closing of the Edit Defaults interface
	
	# Hide the interface
	GUI.EditDefaultsInterface.hide()
	
	# Set the Animation Generator and VarsTracker Default values according to the information proviedd in the interface
	# Make sure to use the 'value' or 'selected' to get the correct piece of information
	# The editor should throw an error if you for get because othe variables should be ducktyped
	vars_tracker.DefaultDirectionSet = GUI.opt_DefaultDirectionSet.selected
	vars_tracker.DefaultSpriteHeight = GUI.spin_DefaultSpriteHeight.value
	vars_tracker.DefaultSpriteWidth = GUI.spin_DefaultSpriteWidth.value
	vars_tracker.DefaultAnimationLength = GUI.spin_DefaultAnimLength.value
	vars_tracker.DefaultAnimationStep = GUI.spin_DefaultAnimStep.value
	# Set the default direction set text based on the selected value of the dropdown
	GUI.lbl_DefaultDirectionSet.text = _set_direction_set_text(GUI.opt_DefaultDirectionSet.selected)
	# Save your changes to the VarsTracker
	Saver.save_vars_tracker()
	# Reload references and refresh the GUI to reflect the changes
	if vars_tracker.CharacterList.has(character_name):
		_handle_loaded_refs()
	_refresh_default_values()
	_set_default_directions_labels()


func _set_default_directions_labels() -> void:
	# Sets up teh labels to display the default directions
	
	# Remove any existing labels
	for child in GUI.grid_DefaultDirectionsInSet.get_children():
			child.queue_free()
	
	# Add a label for each direction
	for direction in vars_tracker.DefaultDirections:
		# Create thelabel
		var direction_label := lbl_DefaultGUILabel.instance()
		# Set the label's text to a formatted version of the direction
		direction_label.text = vars_tracker.Directions.keys()[direction].capitalize()
		# Add the label as a child
		GUI.grid_DefaultDirectionsInSet.add_child(direction_label)


func _setup_default_values() -> void:
	# Sets the values for a state to defaults
	GUI.lbl_DefaultSpriteSize.text = "%spx by %spx" % [str(vars_tracker.DefaultSpriteHeight), str(vars_tracker.DefaultSpriteWidth)]
	GUI.lbl_DefaultDirectionSet.text = _set_direction_set_text(vars_tracker.DefaultDirectionSet)
	GUI.lbl_InfoTexturePath.text = "No texture assigned to state.  Click 'Edit State' to assign."
	GUI.lbl_PlayerScript.text = player_character_script.substr(player_character_script.rfind("/") + 1)
	GUI.lbl_CharacterScript.text = base_character_script.substr(base_character_script.rfind("/") + 1)
	_set_default_directions_labels()
	_set_default_animations_labels()


func _run_first_time_setup() -> void:
	# Runs on the first time the addon is activated in the project.
	# Runs based on whether the AutoAnimVarsTracker.tres file is present in its default location.
	
	# Check for he VarsTracker file
	if !ResourceLoader.exists(vars_tracker_path):
		# Make a new one if it doesn't exist
		var new_vars_tracker = VarsTracker.new()
		ResourceSaver.save(vars_tracker_path, new_vars_tracker)
		vars_tracker = load(vars_tracker_path)
		# Check again if it exists...
		if !ResourceLoader.exists(vars_tracker_path):
			# ... and if not, error out with instructions
			printerr("Cannot create Vars Tracker.  Please manually create the AutoAnimVarsTracker.tres Resource in the Autoanim/Resources folder by duplicating the res://addons/Autoanim/AutoAnimVarsTrackerDefault.tres file.")
			printerr("After this is created, please turn the Autoanim plugin off and on again in your Project Settings.")
			return
	
	# Pull the editor's viewport size for popups
	var editor_viewport_rect = editor_interface.get_viewport().get_visible_rect()
	# Popup the First Time Setup Popup Panel
	GUI.FirstTimeSetupPopup.popup_centered(Vector2(editor_viewport_rect.size.x / 1.25, editor_viewport_rect.size.y / 1.25 ))
	# Disable the Save & Close button until the Diretories are assigned (other functions will enable this button)
	GUI.btn_FTSSaveClose.disabled = true
	
	
	# Wait for the Save & Close button to be pressed
	yield(GUI.btn_FTSSaveClose, "pressed")
	
	# Upon pressing save & close, the VarsTracker will take all provided values and eb saved
	vars_tracker.DefaultAnimationLength = GUI.spin_FTSAnimLength.value
	vars_tracker.DefaultAnimationStep = GUI.spin_FTSAnimStep.value
	vars_tracker.DefaultDirectionSet = GUI.opt_FTSDirectionSet.selected
	vars_tracker.DefaultSpriteHeight = GUI.spin_FTSSpriteHeight.value
	vars_tracker.DefaultSpriteWidth = GUI.spin_FTSSpriteWidth.value
	vars_tracker.CharacterDirectory = GUI.lbl_FTSCharacterDirectory.text
	vars_tracker.AssetDirectory = GUI.lbl_FTSAssetDirectory.text
	Saver.save_vars_tracker()



#------------------------------------------------------------------------------------------------------------------
## EDIT STATE FUNCTIONS
# Thees functions manage the currently selected state

func _on_StateButton_pressed(state :String) -> void:
	## Pull a ref to the animation tree
	_check_working_node_refs()
	var anim_tree :AnimationTree = working_character.animTree
	
	## Pull refs to the state machine and the state therein
	var state_machine :AnimationNodeStateMachine = anim_tree.tree_root
	var working_state :AnimationNodeBlendSpace2D = state_machine.get_node(state)
	
	## Set the selected state, calling the setter
	self.selected_state = state
#	print("DETAILS ON STATE_BUTTON_PRESS:")
#	print(working_character.animation_data.states_details_map[state])
	## Verify whether a texture is already assigned in the ADR
	if working_character.animation_data.states_details_map[selected_state]["texture"] != "":
		## If a texture is assigned, load it and set it up to display in the State Info panel
		GUI.trect_InfoStateTexture.texture = load(working_character.animation_data.states_details_map[selected_state]["texture"])
		GUI.lbl_InfoTexturePath.text = "Texture Path: " + working_character.animation_data.states_details_map[selected_state]["texture"]
	else:
		## If no texture is assigned, set all State Info labels appropriately
		GUI.trect_InfoStateTexture.texture = null
		GUI.lbl_InfoTexturePath.text = "No texture assigned to state.  Click 'Edit State' to assign."
	
	## Set the information displayed to reflect what's in teh ADR for the given state
	GUI.lbl_StateInfoHeader.text = "INFO FOR STATE: " + state.to_upper()
	GUI.lbl_InfoSpriteSize.text = "%s px by %s px" % [
		working_character.animation_data.states_details_map[state]["sprite_width"], 
		working_character.animation_data.states_details_map[state]["sprite_height"]
		]
	GUI.lbl_InfoBlendTreeNodeCount.text = str(working_state.get_blend_point_count())
	GUI.lbl_InfoBlendTreeTrisCount.text = str(working_state.get_triangle_count())
	GUI.lbl_InfoAnimStep.text = str(working_character.animation_data.states_details_map[state]["anim_step"])
	GUI.lbl_InfoAnimLength.text = str(working_character.animation_data.states_details_map[state]["anim_length"])
	
	## Pull the transitions and parse them for output
	var transition_output :String = ""
	var transitions := _get_state_transitions(working_character, state)
	for item in transitions:
		transition_output += str(item) + ": " + str(transitions[item]) + "\n"
	transition_output.erase(transition_output.length() - 1, 1)
	GUI.lbl_InfoStateTransitions.text = transition_output


func _on_EditState_pressed() -> void:
	## Verify that the instance of the Working Character is valid
	_handle_loaded_refs()
	
	## Verify that the animTree, animPlayer, and sprite variables are correctly assigned on the Working Character
	_check_working_node_refs()

	## Pull a static reference to the states_details_map to avoid accidentally changing a value
	var anim_data :AnimationData = working_character.animation_data
	var details :Dictionary = anim_data.states_details_map[selected_state]
#	print("DETAILS ON EDIT STATE PRESS: ", details)
	## Set all GUI labels in the Edit State interface to reflect the data in the ADR
	GUI.vp_SpritePreview.size = GUI.vpc_SpritePreview.rect_size
	GUI.lbl_ESAnimPlayer.text = str(working_character.animPlayer.name)
	GUI.lbl_ESAnimTree.text = str(working_character.animTree.name)
	GUI.lbl_ESInfoHeader.text = "STATE INFO FOR %s'S %s STATE" % [character_name, selected_state]
	GUI.lbl_ESTexturePath.text = details["texture"]
#	print("Sprite width: %s\n Sprite height: %s" %[details["sprite_width"], details["sprite_height"]])
	GUI.spin_ESSpriteHeight.value = details["sprite_height"]
#	print("SpriteHeight Spin Value: ", GUI.spin_ESSpriteHeight.value)
	GUI.spin_ESSpriteWidth.value = details["sprite_width"]
#	print("SpriteWidth Spin Value: ", GUI.spin_ESSpriteWidth.value)
	GUI.spin_ESAnimStep.value = details["anim_step"]
	GUI.spin_ESAnimLength.value = details["anim_length"]
	GUI.cbox_ESLooping.pressed = details["looping"]
	
	## Verify whether a texture path is provided
	if details["texture"] == "":
		## If no texture path is provided, tell the user
		GUI.trect_ESTexture.texture = null
		GUI.lbl_ESFrames.text = "N/A"
		GUI.lbl_ESVFrames.text = "N/A"
		GUI.lbl_ESHFrames.text = "N/A"
		GUI.lbl_ESGenerationResults.text = "Please choose a texture above..."
		GUI.lbl_ESGenerationResults.self_modulate = Color.aquamarine
		GUI.btn_ESGenerateAnims.disabled = true
	else:
		## If a texture is provided, load it into the GUI
		var state_texture = load(working_character.animation_data.states_details_map[selected_state]["texture"])
		var character_sprite :Sprite = working_character.get_node("CharacterSprite")
		character_sprite.texture = state_texture
		_save_character(working_character)
		_calculate_frames_on_texture(state_texture)
		GUI.trect_ESTexture.texture = state_texture
		character_sprite.texture = state_texture
		character_sprite.vframes = working_character.animation_data.states_details_map[selected_state]["vframes"]
		character_sprite.hframes = working_character.animation_data.states_details_map[selected_state]["hframes"]
		character_sprite.frame = 0
		GUI.lbl_ESGenerationResults.text = ""
		_update_edit_state_info_panel()
		
	# Set the stretch shrink value of the Viewport Container to default (1) -- uses te same function as pressing the scale buttons
	
	
	# If the working character has animations for the given state...
	_check_working_node_refs()
	if working_character.animPlayer.get_animation_list().has(selected_state.capitalize() \
		+ working_character.animation_data.directions[0].capitalize()):
		# ... add the animations as options in teh Preview Animation dropdown...
		for direction in working_character.animation_data.directions:
			GUI.opt_ESPreviewAnimation.add_item(selected_state.capitalize() + direction.capitalize())
		# ...select the first option
		GUI.opt_DefaultDirectionSet.selected = 0
#		
	# Pull the size of the editor interface.. 
	var editor_viewport_rect = editor_interface.get_viewport().get_visible_rect()
	# ... and use it to pop up the Edit State interface
	GUI.EditStateInterface.popup_centered(
		Vector2(editor_viewport_rect.size.x / 2, editor_viewport_rect.size.y / 2)
	)
	## Set up the character preview by adding the Working Character instance to the scene tree
	if GUI.opt_ESPreviewAnimation.get_item_count() > 0:
		
		_reload_character_preview()
		
	## Set the position to be centered in the preview space
	working_character.position = Vector2(
		GUI.vpc_SpritePreview.rect_size.x / 2,
		GUI.vpc_SpritePreview.rect_size.y / 2
		)
	_on_ScaleButton_pressed(1)

func _on_ESSpriteSize_value_changed(value :int, spin :SpinBox) -> void:
	# Set the sprite size when the spin value is changed
	if spin == GUI.spin_ESSpriteHeight:
		working_character.animation_data.states_details_map[selected_state]["sprite_height"] = value
	if spin == GUI.spin_ESSpriteWidth:
		working_character.animation_data.states_details_map[selected_state]["sprite_width"] = value
	if GUI.trect_ESTexture.texture != null:
		# If a texture is selected, calculate the new amount of frames and update the info labels accoringly
		_calculate_frames_on_texture(GUI.trect_ESTexture.texture)
		_update_edit_state_info_panel()
		# Reload the character preview to reflect changes
		_reload_character_preview()
		
	# Save and reload the character reference
	_save_character(working_character)
	_handle_loaded_refs()


func _on_ESAnimLength_value_changed(value :float) -> void:
	# Updates the VarsTracker when changes are made to the animation length
	working_character.animation_data.states_details_map[selected_state]["anim_length"] = value
	# Save and reload the character reference
	_save_character(working_character)
	_handle_loaded_refs()


func _on_ESAnimStep_value_changed(value :float) -> void:
	# Updates the VarsTracker when changes are made to the animation step
	working_character.animation_data.states_details_map[selected_state]["anim_step"] = value
	# Save and reload the character reference
	_save_character(working_character)
	_handle_loaded_refs()


func _on_ScaleButton_pressed(value :int) -> void:
	# Sets the scale of the character preview based on the value of the button pressed
	GUI.vpc_SpritePreview.stretch_shrink = value
	GUI.lbl_ESZoom.text = "Zoom: %sx" % value
	for child in GUI.vp_SpritePreview.get_children():
		if child is BaseCharacter:
			# Calculate the position to center the preview
			child.position = Vector2(
				GUI.vpc_SpritePreview.rect_size.x / (2 * value),
				GUI.vpc_SpritePreview.rect_size.y / (2 * value)
				)


func _on_ChooseTexture_pressed() -> void:
	# Pops up the Choose Texture dialog
	var editor_viewport_rect = editor_interface.get_viewport().get_visible_rect()
	GUI.ChooseTextureDialogue.current_dir = vars_tracker.AssetDirectory
	GUI.ChooseTextureDialogue.dialog_text = "Choose the texture for %s's %s State" % [character_name, selected_state]
	GUI.ChooseTextureDialogue.popup_centered(
			Vector2(editor_viewport_rect.size.x / 2, editor_viewport_rect.size.y / 2)
		)


func _on_ChooseTextureDialog_file_selected(path :String) -> void:
	# Sets the state's texture in the states_details_map to the chosen file
	
	# Set the 'texture' valeu to the chosen path
	working_character.animation_data.states_details_map[selected_state]["texture"] = path
#	print("Texture in ADR: ", working_character.animation_data.states_details_map[selected_state]["texture"])
	
	# Load the texture for use
	var state_texture :Texture = load(path)
#	print("StateTexture: ", state_texture)

	# Pull a reference to the character's CharacterSprite node
	var sprite :Sprite = working_character.get_node("CharacterSprite")
	
	# Set the interface segments to reflect teh texture change
	GUI.trect_InfoStateTexture.texture = state_texture
	GUI.trect_ESTexture.texture = state_texture
	GUI.lbl_ESTexturePath.text = path
	GUI.lbl_InfoTexturePath.text = path
	
	# Remove any state generation label contents
	GUI.lbl_ESGenerationResults.text = ""
	
	# Calculate the rames base on the texture
	_calculate_frames_on_texture(state_texture)
	
	# Set the sprite's texture to the chosen texture
	if sprite.texture != null:
		sprite.texture = state_texture
	
	# Set the VFrames and HFrames on the sprite accordingly
	sprite.vframes = working_character.animation_data.states_details_map[selected_state]["vframes"]
	sprite.hframes = working_character.animation_data.states_details_map[selected_state]["hframes"]
	# Set the frame to 0 as the default position
	sprite.frame = 0
	
	# Allow the generation of the animations now that a file is selected
	GUI.btn_ESGenerateAnims.disabled = false
	
	# Saver and reload the character, then update the GUI info segments
	_save_character(working_character)
	_reload_character_preview()
	_update_edit_state_info_panel()


func _on_Looping_toggled(value :bool) -> void:
	# Sets whether the animation should loop
	working_character.animation_data.states_details_map[selected_state]["looping"] = value


func _reload_character_preview() -> void:
	# Reloads the character preview to ensure the most up-to-date version of the character is being shown
	
	# Remove all children from the viewport
	for child in GUI.vp_SpritePreview.get_children():
		GUI.vp_SpritePreview.remove_child(child)
	if working_character.get_parent() == GUI.vp_SpritePreview:
		_handle_loaded_refs()
		_check_working_node_refs()
		return
	_check_working_node_refs()
	var anim_player :AnimationPlayer = working_character.animPlayer
	var state_animations_list :Array = []
	for animation in anim_player.get_animation_list():
		if animation.begins_with(selected_state):
			state_animations_list.append(animation)
		
	if state_animations_list.size() > 0:
		var direction :String 
		if GUI.opt_ESPreviewAnimation.get_item_count() > 0:
			direction = GUI.opt_ESPreviewAnimation.get_item_text(GUI.opt_ESPreviewAnimation.selected).replace(selected_state.capitalize(), "")
		else:
			direction = "South"
		_set_animation_direction_in_tree(direction)
	GUI.vpc_SpritePreview.stretch_shrink = 1
	_on_ScaleButton_pressed(1)
#	var direction :String 
#	if GUI.opt_ESPreviewAnimation.get_item_count() > 0:
#		direction = GUI.opt_ESPreviewAnimation.get_item_text(GUI.opt_ESPreviewAnimation.selected).replace(selected_state.capitalize(), "")
#	else:
#		direction = "South"
#	_set_animation_direction_in_tree(direction)
	GUI.vp_SpritePreview.add_child(working_character)


func _on_GenerateAnims_pressed() -> void:
	print("Creating animations...")
	GUI.lbl_ESGenerationResults.text = ""
	GUI.lbl_ESGenerationResults.self_modulate = Color.white
	GUI.opt_ESPreviewAnimation.clear()
	
	AnimGenerator.create_animations(working_character, selected_state)
	yield(AnimGenerator, "animations_created")
	
	_save_character(working_character)
	_reload_character_preview()
	
	_check_working_node_refs()
	var anim_tree :AnimationTree = working_character.get_node("AnimationTree")
	var anim_state :AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
	working_character.get_node("CharacterSprite").texture = load(working_character.animation_data.states_details_map[selected_state]["texture"])
	for animation in working_character.animPlayer.get_animation_list():
		if animation.begins_with(selected_state):
			GUI.opt_ESPreviewAnimation.add_item(animation)

#	if GUI.opt_ESPreviewAnimation.get_item_count() > 0:
#		working_character.get_node("CharacterSprite/SpriteAnimationPlayer").play(selected_state.capitalize() + working_character.animation_data.directions[0].capitalize())
	for index in GUI.opt_ESPreviewAnimation.get_item_count():
		if GUI.opt_ESPreviewAnimation.get_item_text(index) == selected_state.capitalize() + working_character.animation_data.directions[0].capitalize():
			GUI.opt_ESPreviewAnimation.selected = index
#	working_character.animPlayer.stop()
	anim_tree.set("parameters/" + selected_state.capitalize() + "/blend_position", Vector2(0,1.1))
#	print(anim_tree.get_property_list())
	anim_state.start(selected_state)
#	working_character.get_node("CharacterSprite/SpriteAnimationPlayer").stop()
	GUI.lbl_ESGenerationResults.text = "Animations created!"# % working_character.get_node("CharacterSprite/SpriteAnimationPlayer").get_animation_list().size()
	GUI.lbl_ESGenerationResults.self_modulate = Color.green
	_on_ScaleButton_pressed(1)


func _on_ESPreviewAnimation_item_selected(index :int) -> void:
	# Plays the preview animation based on the item selected
	var direction :String = GUI.opt_ESPreviewAnimation.get_item_text(GUI.opt_ESPreviewAnimation.selected).replace(selected_state.capitalize(), "")
	_set_animation_direction_in_tree(direction)


func _set_animation_direction_in_tree(direction :String) -> void:
	# Sets the animation and direction via the animation tree rather than the animation player
	_check_working_node_refs()
	var anim_tree :AnimationTree = working_character.animTree
	var anim_player :AnimationPlayer = working_character.animPlayer
	var anim_state_machine :AnimationNodeStateMachine = anim_tree.tree_root
	var anim_state :AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
#	print("Direction on autoanim.gd: ", direction)
	var blend_position :Vector2
	match direction:
		"South" :
			blend_position = Vector2(0, 1.1)
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
			printerr("Direction %s not found.  Please check the directions array on %s's ADR." % [direction, working_character.character_name])
	anim_tree["parameters/%s/blend_position" % selected_state.capitalize()] = blend_position
#	print("Current blend_position: " , anim_tree["parameters/StateMachine/%s/blend_position" % selected_state.capitalize()])
	
	if anim_state_machine.has_node(selected_state.capitalize()):
#		print("Node found: ", selected_state.capitalize())
		anim_state.start(selected_state.capitalize())


func _update_edit_state_info_panel()-> void:
	var details :Dictionary = working_character.animation_data.states_details_map[selected_state]
	GUI.lbl_ESFrames.text = str(details.frames)
	GUI.lbl_ESHFrames.text = str(details.hframes)
	GUI.lbl_ESVFrames.text = str(details.vframes)


func _on_ESSave_pressed() -> void:
	working_character.animation_data.states_details_map[selected_state]["anim_step"] = GUI.spin_ESAnimStep.value
	working_character.animation_data.states_details_map[selected_state]["anim_length"] = GUI.spin_ESAnimLength.value
	working_character.animation_data.states_details_map[selected_state]["texture"] = GUI.lbl_ESTexturePath.text
	working_character.animation_data.states_details_map[selected_state]["vframes"] = int(GUI.lbl_ESVFrames.text)
	working_character.animation_data.states_details_map[selected_state]["hframes"] = int(GUI.lbl_ESHFrames.text)
	working_character.animation_data.states_details_map[selected_state]["looping"] = GUI.cbox_ESLooping.pressed
	working_character.animation_data.states_details_map[selected_state]["frames"] = int(GUI.lbl_ESFrames.text)
	working_character.animation_data.states_details_map[selected_state]["frames_on_texture"] = []
	working_character.animation_data.states_details_map[selected_state]["sprite_width"] = GUI.spin_ESSpriteWidth.value
	working_character.animation_data.states_details_map[selected_state]["sprite_height"] = GUI.spin_ESSpriteHeight.value
	_save_character(working_character)
	_reload_character_preview()
	_check_working_node_refs()
	_update_edit_state_info_panel()


func _on_ESSaveClose_pressed() -> void:
	working_character.animation_data.states_details_map[selected_state]["anim_length"] = GUI.spin_ESAnimLength.value
	working_character.animation_data.states_details_map[selected_state]["texture"] = GUI.lbl_ESTexturePath.text
	working_character.animation_data.states_details_map[selected_state]["vframes"] = int(GUI.lbl_ESVFrames.text)
	working_character.animation_data.states_details_map[selected_state]["hframes"] = int(GUI.lbl_ESHFrames.text)
	working_character.animation_data.states_details_map[selected_state]["looping"] = GUI.cbox_ESLooping.pressed
	working_character.animation_data.states_details_map[selected_state]["frames"] = int(GUI.lbl_ESFrames.text)
	working_character.animation_data.states_details_map[selected_state]["frames_on_texture"] = []
	working_character.animation_data.states_details_map[selected_state]["sprite_width"] = GUI.spin_ESSpriteWidth.value
	working_character.animation_data.states_details_map[selected_state]["sprite_height"] = GUI.spin_ESSpriteHeight.value
	working_character.position = Vector2.ZERO
	_save_character(working_character)
	for child in GUI.vp_SpritePreview.get_children():
		GUI.vp_SpritePreview.remove_child(child)
	_refresh_state_info_panel()
	GUI.EditStateInterface.hide()


func _on_ResetStatetoDefault_pressed() -> void:
	GUI.ConfirmationDialoguePopup.dialog_text = "Reset %s state on %s " % [selected_state, character_name] \
		+ "to default values?/n WARNING: Doing so will remove all " \
		+ "customizations to this state on this character " \
		+ "and make them match the Default Values defined in the Default Values box in " \
		+ "the AutoAnim addon."
	GUI.ConfirmationDialoguePopup.window_title = "Reset %s state on %s?" % [selected_state, character_name]
	var editor_viewport_rect = editor_interface.get_viewport().get_visible_rect()
	GUI.ConfirmationDialoguePopup.popup_centered(
			Vector2(editor_viewport_rect.size.x / 2, editor_viewport_rect.size.y / 2)
			)
	yield(GUI.ConfirmationDialoguePopup, "confirmed")
#	print("Resetting %s state on %s" % [selected_state, working_character])
	var animation_data :AnimationData = working_character.animation_data
#	print("   Reset state animation data ref: " ,animation_data)
	animation_data.directions.clear()
	for direction in vars_tracker.DefaultDirections:
		animation_data.directions.append(vars_tracker.Directions.keys()[direction].capitalize())
	animation_data.states_details_map[selected_state].clear()
	animation_data.states_details_map[selected_state] = {
		"anim_step" : vars_tracker.DefaultAnimationStep,
		"anim_length" : vars_tracker.DefaultAnimationLength,
		"texture" : "",
		"vframes" : 0,
		"hframes" : 0,
		"looping" : false,
		"frames" : 0,
		"frames_on_texture" : [],
		"sprite_width" : vars_tracker.DefaultSpriteWidth,
		"sprite_height" : vars_tracker.DefaultSpriteWidth
		}
		
	## ADD REMOVAL OF ALL ANIMATIONS ON ANIMATIONPLAYER ##
	if !working_character.animPlayer:
		_check_working_node_refs()
	var anim_player :AnimationPlayer = working_character.animPlayer
	for animation in anim_player.get_animation_list():
		if animation.begins_with(selected_state):
			anim_player.remove_animation(animation)
	_save_character(working_character)
	GUI.trect_InfoStateTexture.texture = null
	_show_character_data()
	_refresh_state_info_panel()


func _get_state_transitions(character :BaseCharacter, state :String) -> Dictionary:
	var transitions :Dictionary = {}
	var state_machine :AnimationNodeStateMachine = character.animTree.tree_root
	var character_states :Array = _get_states_from_character(character)
	var n := 1
	for comp_state in character_states:
		if state_machine.has_transition(state, comp_state):
			transitions[n] = state + " to " + comp_state
			n += 1
		if state_machine.has_transition(comp_state, state):
			transitions[n] = comp_state + " to " + state
			n += 1
	return transitions


func _calculate_frames_on_texture(texture :Texture) -> void:
#	print("Calculating size of ",  texture, "...")
	var texture_size :Vector2 = texture.get_size()
#	working_character.animation_data.states_details_map[selected_state]["sprite_height"] = GUI.spin_ESSpriteHeight.value
#	working_character.animation_data.states_details_map[selected_state]["sprite_width"] = GUI.spin_ESSpriteWidth.value
	var vframes :int = int(texture_size.y / working_character.animation_data.states_details_map[selected_state]["sprite_height"])
	var hframes :int = int(texture_size.x / working_character.animation_data.states_details_map[selected_state]["sprite_width"])
	var frames_total = int(vframes * hframes)
	working_character.animation_data.states_details_map[selected_state]["vframes"] = vframes
	working_character.animation_data.states_details_map[selected_state]["hframes"] = hframes
	working_character.animation_data.states_details_map[selected_state]["frames"] = frames_total
#	Saver.save_character_adr(working_character.animation_data)


func _on_ResetStates_pressed() -> void:
	GUI.ConfirmationDialoguePopup.dialog_text = "Reset states to default on character" \
	+ " '%s'? \n\nDoing so will remove any character-specific states," % character_name \
	+ " remove all travel paths, and replace everything with a fresh setup copied from the Base Character." 
	var editor_viewport_rect = editor_interface.get_viewport().get_visible_rect()
	GUI.ConfirmationDialoguePopup.popup_centered(
			Vector2(editor_viewport_rect.size.x / 5, editor_viewport_rect.size.y / 5)
			)
	yield(GUI.ConfirmationDialoguePopup, "confirmed")
	_reset_states_on_character_to_default()
#	AnimGenerator.populate_states_adr(working_character) # need to check later
	_refresh_states_buttons(_get_states_from_character(working_character))


func _on_ESPullRefs_pressed() -> void:
	_check_working_node_refs()
	GUI.lbl_ESAnimPlayer.text = str(working_character.animPlayer)
	GUI.lbl_ESAnimTree.text = str(working_character.animTree)


func _on_EditStateInterface_popup_hide()-> void:
	for child in GUI.vp_SpritePreview.get_children():
		GUI.vp_SpritePreview.remove_child(child)
	GUI.opt_ESPreviewAnimation.clear()


func _check_working_node_refs() -> void:
	if working_character:
		if !working_character.animPlayer:
			working_character.animPlayer = working_character.get_node("CharacterSprite/SpriteAnimationPlayer")
		if !working_character.animTree:
			working_character.animTree = working_character.get_node("AnimationTree")
		if !working_character.sprite:
			working_character.sprite = working_character.get_node("CharacterSprite")
#	else:
#		print("No working_character")



#------------------------------------------------------------------------------------------------------------------
## SETTERS AND GETTERS

func set_selected_state(value :String = "") -> void:
	selected_state = value
	if selected_state == "":
		GUI.btn_EditState.disabled = true
		GUI.btn_ResetStatetoDefault.disabled = true
	else:
		GUI.btn_EditState.disabled = false
		GUI.btn_ResetStatetoDefault.disabled = false



#------------------------------------------------------------------------------------------------------------------
## OTHER PLUGIN FUNCTIONS

func _on_ResetAutoAnim_pressed() -> void:
	if !_first_setup:
		GUI.ConfirmationDialoguePopup.dialog_text = "Are you ABSOLUTELY SURE that you want to reset " \
		+ "the addon? \n\n Doing so will remove all customizations and you will need to disable and " \
		+ "re-enable it to use it again."
		GUI.ConfirmationDialoguePopup.self_modulate = Color.red
		var editor_viewport_rect = editor_interface.get_viewport().get_visible_rect()
		GUI.ConfirmationDialoguePopup.popup_centered(
				Vector2(editor_viewport_rect.size.x / 5, editor_viewport_rect.size.y / 5)
				)
		yield(GUI.ConfirmationDialoguePopup, "confirmed")
		var dir :Directory = Directory.new()
		dir.remove(vars_tracker_path)
		vars_tracker = null
		make_visible(false)
		var wr :WeakRef = weakref(vars_tracker)
		if wr.get_ref():
				vars_tracker = null
				if wr.get_ref():
					printerr("Unable to unload vars_tracker from memory...")
					return
		file_system.scan()
		if dir.file_exists(vars_tracker_path):
			printerr("Failed to reset addon")
			return
		_first_setup = true
		if !_first_setup:
			printerr("Failed to set _first_setup properly.")
	else:
		printerr("You need to set up the AutoAnim addon before you can reset it!")



#------------------------------------------------------------------------------------------------------------------
## RESOUCE BUG FIXES AND ERROR CATCHING

func _blow_out_adr_path(path :String) -> AnimationData:
	var blank_adr := AnimationData.new()
	blank_adr.take_over_path(path)
	return blank_adr


func _save_character(character :BaseCharacter) -> bool:
	if !Saver.pack_and_save_character(character):
		printerr("Failed to pack and save Character via _save_character on autoanim.gd.")
		return false
	return true


func open_weblink_to(site :String) -> void:
	OS.shell_open(site)
