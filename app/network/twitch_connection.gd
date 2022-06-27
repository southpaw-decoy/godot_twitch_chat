extends Node
class_name TwitchConnector

# based off of the follow made for Godot 3.x
# https://github.com/MennoMax/gift

# to check if it is connected to twitch
# websocket.is_connected()

# 1. run connect_to_twitch()
# 2. wait for signal twitch_connected
# 3. run authenticate_oauth(nick: String, token : String)
#		authenticate_oauth("justinfan770121", "<oauth_token>")
# 4. wait for signal login_attempt(was_successful) == true
# 5. run join_channel("channel_name")

#
signal channel_joined(channel)
signal channel_left
#

const websocket_url = "wss://irc-ws.chat.twitch.tv:443"
#const twitch_channel_name = "reapz"
var websocket : WebSocketClient = WebSocketClient.new()

# websocket successfully connected to twitch
signal twitch_connected
# connection lost
signal twitch_disconnected
# The connection to twitch failed.
signal twitch_unavailable
# Twitch requested the client to reconnect. (Will be unavailable until next connect)
signal twitch_reconnect
# client tried to login, will return true or false
signal login_attempt(success)
# User sent a message in chat.
signal chat_message(sender_data, message, channel)
# User sent a whisper message.
signal whisper_message(sender_data, message, channel)
# Unhandled data passed through
signal unhandled_message(message, tags)
# A command has been called with invalid arg count
signal cmd_invalid_argcount(cmd_name, sender_data, cmd_data, arg_ary)
# A command has been called with insufficient permissions
signal cmd_no_permission(cmd_name, sender_data, cmd_data, arg_ary)
# have not hooked up yet
signal pong

# command_prefixes are all the special characters that chat will start with to signal they want to use a command
# most common are !  and @signals that you want to target another viewer
# used in "handle_command" function
@export
var command_prefixes : = ["!"] #array of strings
# Time to wait after each sent chat message. Values below ~0.31 might lead to a disconnect after 100 messages.
@export
var chat_timeout = 0.32
@export
var get_images : bool = false # was false
# If true, caches emotes/badges to disk, so that they don't have to be redownloaded on every restart.
# This however means that they might not be updated if they change until you clear the cache.
@export
var disk_cache : bool = false # was false
# Disk Cache has to be enbaled for this to work
@export
var disk_cache_path = "user://gift/cache"  # will need to be changd when caching images is implemented

### the below is for downloading cached images, which is not supported yet
# Emote has been downloaded
signal emote_downloaded(emote_id)
# Badge has been downloaded
signal badge_downloaded(badge_name)

# this pulls the chat user' sname out of the message
var username_regex = RegEx.new()
var twitch_restarting

#### not implemeneted yet TODO
# Twitch disconnects connected clients if too many chat messages are being sent. (At about 100 messages/30s)
var chat_queue = [] # not implemented yet
@onready
var chat_accu = chat_timeout  # not implemented yet

# Mapping of channels to their channel info, like available badges
var channels : Dictionary = {}
var commands : Dictionary = {}
#var image_cache : ImageCache # TODO

# Required permission to execute the command
enum PermissionFlag {
	EVERYONE = 0,
	VIP = 1,
	SUB = 2,
	MOD = 4,
	STREAMER = 8,
	# Mods and the streamer
	MOD_STREAMER = 12,
	# Everyone but regular viewers
	NON_REGULAR = 15
}

# Where the command should be accepted
enum WhereFlag {
	CHAT = 1,
	WHISPER = 2
}


func _init():
	websocket.verify_ssl = true
	# this pulls the chat user' sname out of the message
	# it works by pulling all characters between the ! and the @
	username_regex.compile("(?<=!)[\\w]*(?=@)")

func _ready():
	websocket.connect("connection_closed", connection_closed)
	websocket.connect("connection_error", connection_error)
	websocket.connect("connection_established", connection_established)
	websocket.connect("data_received", data_received)
#	websocket.connect("login_attempt", login_result)
	
	# initiate connection to the given URL
#	connect_to_twitch()

func connect_to_twitch() -> void:
	print('connect_to_twitch')
	var err = websocket.connect_to_url(websocket_url)
	print("connection err : ", err)
	if err != OK:
		print("unable to connect")
		set_process(false)
#	emit_signal("twitch_connected")

func _process(delta):
	if(websocket.get_connection_status() != WebRTCMultiplayerPeer.CONNECTION_DISCONNECTED):
		websocket.poll()
		if(!chat_queue.is_empty() && chat_accu >= chat_timeout):
			send(chat_queue.pop_front())
			chat_accu = 0
		else:
			chat_accu += delta

# Login using a oauth token.
# You will have to either get a oauth token yourself or use
# https://twitchapps.com/tokengen/
# to generate a token with custom scopes.
# you can also use Justin plug random numbers and anything for token to join as guest
func authenticate_oauth(nick: String, token : String) -> void:
	websocket.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	send("PASS" + ("" if token.begins_with("oauth:") else "oauth:") + token, true)
	send("NICK " + nick.to_lower())
	request_caps()

func request_caps(caps : String = "twitch.tv/commands twitch.tv/tags twitch.tv/membership") -> void:
	send("CAP REQ :" + caps)

# Sends a String to Twitch.
func send(text : String, token : bool = false) -> void:
	websocket.get_peer(1).put_packet(text.to_utf8_buffer())
	if(OS.is_debug_build()):
		if(!token):
			print("< " + text.strip_edges(false))
		else:
			print("< PASS oauth:******************************") 

# Sends a chat message to a channel. Defaults to the only connected channel.
func chat(message : String, channel : String = ""):
	var keys : Array = channels.keys()
	if(channel != ""):
		chat_queue.append("PRIVMSG " + ("" if channel.begins_with("#") else "#") + channel + " :" + message + "\r\n")
	elif(keys.size() == 1):
		chat_queue.append("PRIVMSG #" + channels.keys()[0] + " :" + message + "\r\n")
	else:
		print_debug("No channel specified.")

func whisper(message : String, target : String):
	chat("/w " + target + " " + message)

func data_received():
#	print("data received")
	var messages : PackedStringArray = websocket.get_peer(1).get_packet().get_string_from_utf8().strip_edges(false).split("\r\n")
#	print("----------------------")
#	print(messages)
	var tags = {}
	for message in messages:
#		print(message)
		if(message.begins_with("@")):
#			print("twitch message received : ", message)
			var msg : PackedStringArray = message.split(" ", false, 1)
			message = msg[1]
			for tag in msg[0].split(";"):
				var pair = tag.split("=")
				tags[pair[0]] = pair[1]
#		if(OS.is_debug_build()): # TODO make this log to a file
#			print("> " + message)  # this will let you see all data in the godot output but really clogs it up
		handle_message(message, tags)
	pass

## Registers a command on an object with a func to call, similar to connect(signal, instance, func).
func add_command(cmd_name : String, target_obj : Object, target_function_name : String, max_args : int = 0, min_args : int = 0, permission_level : int = PermissionFlag.EVERYONE, where : int = WhereFlag.CHAT) -> void:
	print("add comand : " + cmd_name + target_obj.to_string() + target_function_name)
	var callable = Callable(target_obj, target_function_name)
	commands[cmd_name] = CommandData.new(callable, permission_level, max_args, min_args, where)

# Removes a single command or alias.
func remove_command(cmd_name : String) -> void:
	commands.erase(cmd_name)

# Removes a command and all associated aliases.
func purge_command(cmd_name : String) -> void:
	var to_remove = commands.get(cmd_name)
	if(to_remove):
		var remove_queue = []
		for command in commands.keys():
			if(commands[command].Callable == to_remove.Callable):
				remove_queue.append(command)
		for queued in remove_queue:
			commands.erase(queued)

func add_alias(cmd_name : String, alias : String) -> void:
	if(commands.has(cmd_name)):
		commands[alias] = commands.get(cmd_name)

func add_aliases(cmd_name : String, aliases : PackedStringArray) -> void:
	for alias in aliases:
		add_alias(cmd_name, alias)

func handle_message(message : String, tags : Dictionary)->void:
	if(message == ":tmi.twitch.tv NOTICE * :Login authentication failed"):
		print_debug("Authentication failed.")
		emit_signal("login_attempt", false)
		return
	if(message == "PING :tmi.twitch.tv"):
		send("PONG :tmi.twitch.tv")
		emit_signal("pong")
		return
#	print("message : ", message, "   and the tags : ", tags)
	var msg : PackedStringArray = message.split(" ", true, 3)
	
	
	# msg[0] = username in a long string of other stuff, has leading ":" character
	# msg[1] = what TYPE of message it is. We will switch on the below to handle each type of message differently
	# msg[2] = channel name with leading "#" character
	# msg[3] = chat message with leading ":" (used to check for commands since commands can't have spaces)
	# to find the first word, will need to split it again with " " 
	match msg[1]:
		"001":
			print_debug("Authentication successful.")
			emit_signal("login_attempt", true)
		"ROOMSTATE":
			print("joined channel : " + msg[2])
			emit_signal("channel_joined", msg[2])
			
		"PRIVMSG":
			# create an object with the data from the sender, this will be their suername, channel they chatted in, and the tags
			var sender_data : SenderData = SenderData.new(username_regex.search(msg[0]).get_string(), msg[2], tags)
#			print("sender data is showing here : ")
#			print("++++++++++++  " + sender_data.user + " : " + msg[3].right(-1))
			# we now need to see if their chat message started with a command
			handle_command(sender_data, msg)
			
			# message[3] is the actual message they sent, we need to strip the leading character ":" from the beginning
			# we will also emit the entire message in case anyone is listening and wants to know
			emit_signal("chat_message", sender_data, msg[3].right(-1), msg[2])
#			if(get_images):
#				if(!image_cache.badge_map.has(tags["room-id"])):
#					image_cache.get_badge_mappings(tags["room-id"])
#				for emote in tags["emotes"].split("/", false):
#					image_cache.get_emote(emote.split(":")[0])
#				for badge in tags["badges"].split(",", false):
#					image_cache.get_badge(badge, tags["room-id"])
		"WHISPER":
			var sender_data : SenderData = SenderData.new(username_regex.search(msg[0]).get_string(), msg[2], tags)
			handle_command(sender_data, msg, true)
			emit_signal("whisper_message", sender_data, msg[3].right(-1))
		"RECONNECT":
			twitch_restarting = true
		_:
			emit_signal("unhandled_message", message, tags)

func handle_command(sender_data : SenderData, msg : PackedStringArray, whisper : bool = false) -> void:
	if (command_prefixes.has(msg[3].substr(1, 1))): # msg[3] is the actual chat message, but it has a leading ":" which we need to strip off and then just get the beginning char of the chat message to see if it is in the command_prefixes var
		print("func handle_command : chat message started with command_prefix    " + msg[3].right(-2))
		var command : String = msg[3].right(-2)
		var cmd_data : CommandData = commands.get(command)
#		print("command : ", command, "and the data : ", cmd_data)
		if(cmd_data):
			if(whisper == true && cmd_data.where & WhereFlag.WHISPER != WhereFlag.WHISPER):
				return
			elif(whisper == false && cmd_data.where & WhereFlag.CHAT != WhereFlag.CHAT):
				return 
			var args = "" if msg.size() < 5 else msg[4]
			var arg_ary : PackedStringArray = PackedStringArray() if args == "" else args.split(" ")
			if(arg_ary.size() > cmd_data.max_args && cmd_data.max_args != -1 || arg_ary.size() < cmd_data.min_args):
				emit_signal("cmd_invalid_argcount", command, sender_data, cmd_data, arg_ary)
				print_debug("Invalid argcount!")
				return
			if(cmd_data.permission_level != 0):
				var user_perm_flags = get_perm_flag_from_tags(sender_data.tags)
				if(user_perm_flags & cmd_data.permission_level != cmd_data.permission_level):
					emit_signal("cmd_no_permission", command, sender_data, cmd_data, arg_ary)
					print_debug("No Permission for command!")
					return
			if(arg_ary.size() == 0):
				print("command has no args")
#				cmd_data.func_ref(CommandInfo.new(sender_data, command, whisper))
				cmd_data.callable.call(sender_data, command, whisper)
#				self.cmd_data.func_ref(CommandInfo.new(sender_data, command, whisper))
#				cmd_data.func_ref.call_func(CommandInfo.new(sender_data, command, whisper))
			else:
				print("command has args")
#				self.cmd_data.func_ref(CommandInfo.new(sender_data, command, whisper))
				cmd_data.callable.call(sender_data, command, whisper, arg_ary)
				
#				cmd_data.func_ref.call_func(CommandInfo.new(sender_data, command, whisper), arg_ary)

func get_perm_flag_from_tags(tags : Dictionary) -> int:
	var flag = 0
	var entry = tags.get("badges")
	if(entry):
		for badge in entry.split(","):
			if(badge.begins_with("vip")):
				flag += PermissionFlag.VIP
			if(badge.begins_with("broadcaster")):
				flag += PermissionFlag.STREAMER
	entry = tags.get("mod")
	if(entry):
		if(entry == "1"):
			flag += PermissionFlag.MOD
	entry = tags.get("subscriber")
	if(entry):
		if(entry == "1"):
			flag += PermissionFlag.SUB
	return flag

func join_channel(channel : String):
	send("JOIN #" + channel.to_lower())

func leave_channel(channel : String) -> void:
	var lower_channel : String = channel.to_lower()
	send("PART #" + lower_channel)
	channels.erase(lower_channel)
	emit_signal("channel_left")

func connection_established(proto = ''):
	print("connection established with protocol : ", proto)
	websocket.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	websocket.get_peer(1).put_packet('{"type": "PING"}'.to_utf8_buffer())
	emit_signal("twitch_connected")

func connection_closed(was_clean = false):
	if(twitch_restarting):
		print_debug("Reconnecting to Twitch")
		emit_signal("twitch_reconnect")
		connect_to_twitch()
		await self.twitch_connected
		for channel in channels.keys():
			join_channel(channel)
	else:
		print_debug("Disconnected from Twitch")

func connection_error() -> void:
	print_debug("Twitch connection error")
	emit_signal("twitch_unavailable")

#func login_result(result):
#	print("login was : ", result)
#	pass





