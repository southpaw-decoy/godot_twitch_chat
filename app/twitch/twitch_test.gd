extends TwitchConnector

#var twitch_channel_name : String = "jitspoe"

# Called when the node enters the scene tree for the first time.
func _ready():
	super._ready()
	print("ready")
	connect_to_twitch_by_channel_name(twitch_channel_name)
	pass # Replace with function body.


func connect_to_twitch_by_channel_name(twitch_name : String) -> void:
	print('2')
	connect_to_twitch()
#	await self.twitch_connected
#	authenticate_oauth("justinfan77012", "<oauth_token>")
#	if( await self.login_attempt == false):
#		print("Invalid username or token")
#		return
	join_channel(twitch_name)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
