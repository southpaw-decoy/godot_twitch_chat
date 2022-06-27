extends Node

# 1. run connect_to_twitch()
# 2. wait for signal twitch_connected
# 3. run authenticate_oauth(nick: String, token : String)
#		authenticate_oauth("justinfan770121", "<oauth_token>")
# 4. wait for signal login_attempt(was_successful) == true
# 5. run join_channel("channel_name")

#@export
#var twitch_channel_name : String = "southpaw_decoy"

@onready
var ref_twitch_connector : TwitchConnector = find_child("twitch_connection", false, true)

# Called when the node enters the scene tree for the first time.
func _ready():
	ref_twitch_connector.connect("twitch_connected", twitch_connected)
#	ref_twitch_connector.connect("login_attempt", login_attempt)

	ref_twitch_connector.connect_to_twitch()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func twitch_connected():
	print("game manager twitch connected")
	ref_twitch_connector.authenticate_oauth("justinfan770121", "<oauth_token>")
	pass

#func login_attempt(was_successful):
#	if was_successful :
#		ref_twitch_connector.join_channel(twitch_channel_name)
