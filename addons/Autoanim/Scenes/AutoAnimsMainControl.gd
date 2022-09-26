tool
class_name GenerateAnimsGUI
extends Control


# DIRECTORY COLLECTION REFERENCES
onready var btn_SetCharacterDir :Button = $"%btn_SetCharacterDirectory"
onready var btn_SetAssetDir :Button = $"%btn_SetAssetDirectory"
onready var btn_SetCharacterScript :Button = $"%btn_SetCharacterScript"
onready var btn_SetPlayerScript :Button = $"%btn_SetPlayerScript"
onready var lbl_CharacterDir :Label = $"%lbl_CharacterDirectory"
onready var lbl_AssetDir :Label = $"%lbl_AssetDirectory"
onready var lbl_CharacterScript :Label = $"%lbl_CharacterScript"
onready var lbl_PlayerScript :Label  =$"%lbl_PlayerScript"


# FIRST TIME SETUP REFERENCESS
onready var btn_FTSCharacterDirectory :Button = $"%btn_FTSCharacterDirectory"
onready var btn_FTSAssetDirectory :Button = $"%btn_FTSAssetDirectory"
onready var btn_FTSCharacterScript :Button = $"%btn_FTSCharacterScript"
onready var btn_FTSPlayerScript :Button = $"%btn_FTSPlayerScript"
onready var btn_FTSSaveClose :Button = $"%btn_FTSSaveClose"
onready var lbl_FTSCharacterDirectory :Label = $"%lbl_FTSCharacterDirectory"
onready var lbl_FTSAssetDirectory :Label = $"%lbl_FTSAssetDirectory"
onready var lbl_FTSCharacterScript :Label = $"%lbl_FTSCharacterScript"
onready var lbl_FTSPlayerScript :Label = $"%lbl_FTSPlayerScript"
onready var opt_FTSDirectionSet :OptionButton = $"%opt_FTSDirectionSet"
onready var spin_FTSSpriteWidth :SpinBox = $"%spin_FTSSpriteWidth"
onready var spin_FTSSpriteHeight :SpinBox = $"%spin_FTSSpriteHeight"
onready var spin_FTSAnimLength :SpinBox = $"%spin_FTSAnimLength"
onready var spin_FTSAnimStep :SpinBox = $"%spin_FTSAnimStep"
onready var FirstTimeSetupPopup :PopupPanel = $"%FirstTimeSetupPopup"
onready var btn_FTSDiscord :Button = $"%btn_FTSDiscord"
onready var btn_FTSYoutube :Button = $"%btn_FTSYoutube"
onready var btn_FTSPatreon :Button = $"%btn_FTSPatreon"
onready var btn_FTSDocs :Button = $"%btn_FTSDocs"


# CHARACTER MANAGEMENT REFERENCES
onready var btn_RemoveCharacter :Button = $"%btn_RemoveCharacter"
onready var btn_OpenCharacterScene :Button = $"%btn_OpenCharacterScene"
onready var btn_ResetCharacter :Button = $"%btn_ResetCharacter"
onready var btn_AddCharacter :Button = $"%btn_AddCharacter"
onready var btn_PullCharacter :Button = $"%btn_PullCharacter"
onready var btn_MakePlayer :Button = $"%btn_MakePlayer"
onready var lbl_AddCharacterResults :Label = $"%lbl_AddCharacterResults"
onready var lbl_CharacterOutput :Label = $"%lbl_CharacterOutputText"
onready var lbl_CharacterInfoHeader :Label = $"%lbl_CharacterInfoHeader"
onready var line_CharacterName :LineEdit = $"%line_CharacterName"


# ANIMATIONS MANAGEMENT REFERENCES
onready var btn_GenerateAnimations :Button = $"%btn_GenerateAnimations"
onready var btn_ClearAnimations :Button = $"%btn_ClearAnimations"
onready var lbl_GenerationResults :Label = $"%lbl_GenerateResult"


# STATES MANAGMENT REFERENCES
onready var btn_PullStates :Button = $"%btn_PullStates"
onready var btn_ResetStates :Button = $"%btn_ResetStates"
onready var btn_ResetStatetoDefault :Button = $"%btn_ResetStatetoDefault"
onready var btn_EditState :Button = $"%btn_EditState"
onready var grid_StateInfo :HFlowContainer = $"%grid_StateInfo"
onready var grid_StatesButtonGrid :GridContainer = $"%grid_StatesButtonGrid"
onready var lbl_StateInfoHeader :Label = $"%lbl_StateInfoHeader"


# STATES INFO REFERENCES
onready var lbl_InfoSpriteSize :Label = $"%lbl_InfoSpriteSize"
onready var lbl_InfoFrameCount :Label = $"%lbl_InfoFrameCount"
onready var lbl_InfoBlendTreeNodeCount :Label = $"%lbl_InfoBlendTreeNodeCount"
onready var lbl_InfoBlendTreeTrisCount :Label = $"%lbl_InfoBlendTreeTrisCount"
onready var lbl_InfoStateTransitions :Label = $"%lbl_InfoStateTransitions"
onready var lbl_InfoAnimLength :Label = $"%lbl_InfoAnimLength"
onready var lbl_InfoAnimStep :Label = $"%lbl_InfoAnimStep"
onready var lbl_InfoTexturePath :Label = $"%lbl_InfoTexturePath"
onready var trect_InfoStateTexture :TextureRect = $"%trect_InfoStateTexture"
onready var state_info_labels :Array = [
	lbl_InfoSpriteSize,
	lbl_InfoFrameCount,
	lbl_InfoBlendTreeNodeCount,
	lbl_InfoBlendTreeTrisCount,
	lbl_InfoStateTransitions,
	lbl_InfoAnimLength,
	lbl_InfoAnimStep
	]


# MAIN INTERFACE MANAGEMENT REFERENCES
onready var btn_RefreshCharacterList :Button = $"%btn_RefreshCharacterList"
onready var btn_ResetAutoAnim :Button = $"%btn_ResetAutoAnim"
onready var lbl_CharacterCount :Label = $"%lbl_CharacterCount"
onready var CharacterDirectoryPopup :FileDialog = $"%CharacterDirectoryPopup"
onready var AssetDirectoryPopup :FileDialog = $"%AssetDirectoryPopup"
onready var ConfirmationDialoguePopup :ConfirmationDialog = $"%ConfirmationDialog"
onready var EditStateInterface :PopupPanel = $"%EditStateInterface"
onready var ChooseTextureDialogue :FileDialog = $"%ChooseTextureDialogue"
onready var EditDefaultsInterface :PopupPanel = $"%EditDefaultsInterface"
onready var vbox_CharacterList :VBoxContainer = $"%vbox_CharacterList"
onready var ScriptPopup :FileDialog = $"%ScriptPopup"



# DEFAULTS MANAGEMENT REFERENCES
onready var btn_EditDefaults :Button = $"%btn_EditDefaults"
onready var btn_OpenBaseCharacter :Button = $"%btn_OpenBaseCharacter"
onready var grid_DefaultDirectionsInSet :GridContainer = $"%grid_DirectionsInSet"
onready var grid_DefaultAnimations :GridContainer = $"%grid_DefaultAnimations"
onready var lbl_DefaultDirectionSet :Label = $"%lbl_DefaultDirectionSet"
onready var lbl_DefaultSpriteSize :Label = $"%lbl_DefaultSpriteSize"
onready var lbl_DefaultFrameCount :Label = $"%lbl_DefaultFrameCount"
onready var lbl_DefaultLength :Label = $"%lbl_DefaultLengh"
onready var lbl_DefaultStep :Label = $"%lbl_DefaultStep"
onready var lbl_DefaultTrackCount :Label = $"%lbl_DefaultTrackCount"
onready var spin_DefaultAnimLength :SpinBox = $"%spin_DefaultAnimLength"
onready var spin_DefaultAnimStep :SpinBox = $"%spin_DefaultAnimStep"



# EDIT STATE INTERFACE MANAGEMENT REFERENCES
onready var btn_Scale1x :Button = $"%btn_Scale1x"
onready var btn_Scale2x :Button = $"%btn_Scale2x"
onready var btn_Scale3x :Button = $"%btn_Scale3x"
onready var btn_ESSave :Button = $"%btn_EditStateSave"
onready var btn_ESSaveClose :Button = $"%btn_EditStateSaveClose"
onready var btn_ESChooseTexture :Button = $"%btn_EditStateChooseTexture"
onready var btn_ESGenerateAnims :Button = $"%btn_EditStateGenerateAnims"
onready var btn_ESClearAnimations :Button = $"%btn_EditStateClearAnimations"
onready var btn_ESPullRefs :Button = $"%btn_EditStatePullRefs"
onready var cbox_ESLooping :CheckBox = $"%cbox_EditStateLooping"
onready var lbl_ESAnimPlayer:Label = $"%lbl_EditStateAnimPlayer"
onready var lbl_ESAnimTree:Label = $"%lbl_EditStateAnimTree"
onready var lbl_ESInfoHeader :Label = $"%lbl_EditStateInfoHeader"
onready var lbl_ESTexturePath :Label = $"%lbl_EditStateTexturePath"
onready var lbl_ESZoom :Label = $"%lbl_EditStateZoom"
onready var lbl_ESHFrames :Label = $"%lbl_EditStateAnimHFrames"
onready var lbl_ESVFrames :Label = $"%lbl_EditStateAnimVFrames"
onready var lbl_ESFrames :Label = $"%lbl_EditStateAnimFrames"
onready var lbl_ESGenerationResults :Label = $"%lbl_EditStateGenerationResults"
onready var opt_ESPreviewAnimation :OptionButton = $"%opt_EditStatePreviewAnimation"
onready var spin_ESSpriteWidth :SpinBox = $"%spin_EditStateSpriteWidth"
onready var spin_ESSpriteHeight :SpinBox = $"%spin_EditStateSpriteHeight"
onready var spin_ESAnimStep :SpinBox = $"%spin_EditStateAnimStep"
onready var spin_ESAnimLength :SpinBox = $"%spin_EditStateAnimLength"
onready var trect_ESTexture :TextureRect = $"%trect_EditStateTexture"
onready var vpc_SpritePreview :ViewportContainer = $"%vpc_SpritePreview"
onready var vp_SpritePreview :Viewport = $"%vp_SpritePreview"


# EDIT DEFAULTS INTERFACEMANAGEMENT REFERENCES
onready var btn_DefaultsClose :Button = $"%btn_DefaultsClose"
onready var btn_DefaultOpenBaseCharacter :Button = $"%btn_DefaultOpenBaseCharacter"
onready var lbl_DefaultDirectionsInSet :Label = $"%lbl_DefaultDirectionsInSet"
onready var opt_DefaultDirectionSet :OptionButton = $"%opt_DefaultDirectionSet"
onready var spin_DefaultSpriteHeight :SpinBox = $"%spin_DefaultSpriteHeight"
onready var spin_DefaultSpriteWidth :SpinBox = $"%spin_DefaultSpriteWidth"


# OTHER REFS
onready var Saver := $"%Saver"
onready var AnimGenerator := $"%AnimGenerator"


func _ready() -> void:
	lbl_AddCharacterResults.text= ""
	lbl_AssetDir.text = ""
	lbl_CharacterDir.text = ""
	btn_AddCharacter.disabled = true
	btn_PullCharacter.disabled = true
	btn_ResetStates.disabled = true
	btn_ClearAnimations.disabled = true
#	print(AnimGenerator)
