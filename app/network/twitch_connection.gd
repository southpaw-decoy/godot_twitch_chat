extends Node
class_name TwitchConnector

const websocket_url = "wss://irc-ws.chat.twitch.tv:443"
const twitch_channel_name = "lazylazylacey"
var websocket : WebSocketClient = WebSocketClient.new()

# websocket successfully connected to twitch
signal twitch_connected
# client tried to login, will return true or false
signal login_attempt(success)
# have not hooked up yet
signal pong
# Unhandled data passed through
signal unhandled_message(message, tags)

var user_regex = RegEx.new()
var twitch_restarting

func _init():
	websocket.verify_ssl = true
	user_regex.compile("(?<=!)[\\w]*(?=@)")

func _ready():
	websocket.connect("connection_closed", closed)
	websocket.connect("connection_error", closed)
	websocket.connect("connection_established", connection_established)
	websocket.connect("data_received", data_received)
	websocket.connect("login_attempt", login_result)
	
	# initiate connection to the given URL
	connect_to_twitch()
#	print('yep')
#	var err = websocket.connect_to_url(websocket_url)
#	print(err)
#	if err != OK:
#		print("unable to connect")
#		set_process(false)

func connect_to_twitch() -> void:
	print('connect_to_twitch')
	var err = websocket.connect_to_url(websocket_url)
	print("connection err : ", err)
	if err != OK:
		print("unable to connect")
		set_process(false)
	emit_signal("twitch_connected")

func authenticate_oauth(nick: String, token : String) -> void:
	websocket.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	send("PASS" + ("" if token.begins_with("oauth:") else "oauth:") + token, true)
	send("NICK " + nick.to_lower())
	request_caps()

func request_caps(caps : String = "twitch.tv/commands twitch.tv/tags twitch.tv/membership") -> void:
	send("CAP REQ :" + caps)

func closed(was_clean = false):
	print("closed, clean : ", was_clean)

func connection_established(proto = ''):
	print("connection established with protocol : ", proto)
	websocket.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	websocket.get_peer(1).put_packet('{"type": "PING"}'.to_utf8_buffer())
	emit_signal("twitch_connected")
	authenticate_oauth("justinfan770121", "<oauth_token>")
	join_channel(twitch_channel_name)

func login_result(result):
	print("login was : ", result)
	pass

func data_received():
	print("data received")
	var messages : PackedStringArray = websocket.get_peer(1).get_packet().get_string_from_utf8().strip_edges(false).split("\r\n")
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
		if(OS.is_debug_build()):
			print("> " + message)
		handle_message(message, tags)
	pass

func send(text : String, token : bool = false) -> void:
	websocket.get_peer(1).put_packet(text.to_utf8_buffer())
	pass

func join_channel(channel : String):
	send("JOIN #" + channel.to_lower())

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
	var msg : PackedStringArray = message.split(" ", true, 4)
	match msg[1]:
		"001":
			print_debug("Authentication successful.")
			emit_signal("login_attempt", true)
		"PRIVMSG":
#			print("privmsg : ", msg)
#			print("msg[0] : ", msg[0])
#			print("msg[2] : ", msg[2])
#			print("tags : ", tags)
			
			var sender_data : SenderData = SenderData.new(user_regex.search(msg[0]).get_string(), msg[2], tags)
			print("sender data is showing here : ", sender_data)
			handle_command(sender_data, msg)
			emit_signal("chat_message", sender_data, msg[3].right(1))
#			emit_signal("chat_message", msg, msg)
#			if(get_images):
#				if(!image_cache.badge_map.has(tags["room-id"])):
#					image_cache.get_badge_mappings(tags["room-id"])
#				for emote in tags["emotes"].split("/", false):
#					image_cache.get_emote(emote.split(":")[0])
#				for badge in tags["badges"].split(",", false):
#					image_cache.get_badge(badge, tags["room-id"])
		"WHISPER":
			var sender_data : SenderData = SenderData.new(user_regex.search(msg[0]).get_string(), msg[2], tags)
			handle_command(sender_data, msg, true)
			emit_signal("whisper_message", sender_data, msg[3].right(1))
		"RECONNECT":
			twitch_restarting = true
		_:
			emit_signal("unhandled_message", message, tags)

func handle_command(sender_data : SenderData, msg : PackedStringArray, whisper : bool = false) -> void:
	print("handle command", sender_data, " ::: ", msg)
#	if true : # if (command_prefixes.has(msg[3].substr(1, 1))):
##		print("if statment true")
#		var command : String  = msg[3].right(1) #var command : String  = msg[3].right(2)
#		var cmd_data : CommandData = commands.get(command)
##		print("command : ", command, "and the data : ", cmd_data)
#		if(cmd_data):
#			if(whisper == true && cmd_data.where & WhereFlag.WHISPER != WhereFlag.WHISPER):
#				return
#			elif(whisper == false && cmd_data.where & WhereFlag.CHAT != WhereFlag.CHAT):
#				return 
#			var args = "" if msg.size() < 5 else msg[4]
#			var arg_ary : PoolStringArray = PoolStringArray() if args == "" else args.split(" ")
#			if(arg_ary.size() > cmd_data.max_args && cmd_data.max_args != -1 || arg_ary.size() < cmd_data.min_args):
#				emit_signal("cmd_invalid_argcount", command, sender_data, cmd_data, arg_ary)
#				print_debug("Invalid argcount!")
#				return
#			if(cmd_data.permission_level != 0):
#				var user_perm_flags = get_perm_flag_from_tags(sender_data.tags)
#				if(user_perm_flags & cmd_data.permission_level != cmd_data.permission_level):
#					emit_signal("cmd_no_permission", command, sender_data, cmd_data, arg_ary)
#					print_debug("No Permission for command!")
#					return
#			if(arg_ary.size() == 0):
#				print("command has no args")
#				cmd_data.func_ref.call_func(CommandInfo.new(sender_data, command, whisper))
#			else:
#				print("command has args")
#				cmd_data.func_ref.call_func(CommandInfo.new(sender_data, command, whisper), arg_ary)

func _process(_delta):
	websocket.poll()
