extends Control

@onready
var ref_twitch_connector : TwitchConnector = get_parent().find_child("twitch_connection", false, true)
@onready
var ref_rich_text_label : RichTextLabel = $VFlowContainer/RichTextLabel


# Called when the node enters the scene tree for the first time.
func _ready():
	ref_twitch_connector.connect("chat_message", chat_message)
	ref_twitch_connector.connect("channel_joined", channel_joined)
	ref_twitch_connector.add_command("hi", self, "hi")
	pass # Replace with function body.

func channel_joined(channel):
	ref_rich_text_label.add_text("      Joined channel : " + channel + "\n")

func chat_message(sender_data, message, channel):
	ref_rich_text_label.push_bold
	ref_rich_text_label.append_text(sender_data.user)
	ref_rich_text_label.pop
	ref_rich_text_label.append_text(' : ' +message + "\n")

# Check the CommandInfo class for the available info of the cmd_info.
func hi(sender_data : SenderData, command, whisper) -> void:
	print("hello world on chat viewer")

func _on_channel_button_pressed():
	ref_twitch_connector.join_channel($VFlowContainer/HFlowContainer/VFlowContainer/channel_te.text)
	pass # Replace with function body.

func _on_add_command_button_pressed():
	ref_twitch_connector.add_command($VFlowContainer/HFlowContainer/VFlowContainer2/add_command_te.text, self, $VFlowContainer/HFlowContainer/VFlowContainer2/add_command_te.text)
	pass # Replace with function body

func _on_remove_command_button_pressed():
	ref_twitch_connector.remove_command($VFlowContainer/HFlowContainer/VFlowContainer3/remove_command_te.text)
	pass # Replace with function body.
