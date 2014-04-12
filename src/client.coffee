net = require "net"
path = require "path"
EventEmitter = require('events').EventEmitter
parseMessage = require "irc-message"

Channel = require './channel'

defaultOpt =
	port: 6667
	nick: "NodeIRCClient"
	username: "NodeIRCClient"
	realname: "NodeIRCClient"
	verbose: true
	channels: []
	users: []
	autoNickChange: true
	autoRejoin: false		#
	autoConnect: true
	autoSplitMessage: true	#
	messageDelay: 1000		#

getSender = (parsedReply) ->
	if parsedReply.prefixIsHostmask()
		return parsedReply.parseHostmaskFromPrefix().nickname
	else if parsedReply.prefix?
		return parsedReply.prefix
	return undefined

###
An IRC Client.
@author Rahat Ahmed
###
class Client extends EventEmitter
	###
	Constructor for Client.
	@option opt [String] server The server address to connect to
	@option opt [Integer] port The port to connect to. Default: 6667
	@option opt [String] nick The nickname to connect with. Default: NodeIRCClient
	@option opt [String] username The username to connect with. Default: NodeIRCClient
	@option opt [String] realname The real name to connect with. Default: NodeIRCClient
	@option opt [Array] channels The channels to autoconnect to on connect. Default: []
	@option opt [Boolean] verbose Whether this should output log messages to console or not. Default: true
	@option opt [Boolean] autoNickChange Whether this should try alternate nicks if the given one is taken, or give up and quit. Default: true
	@option opt [Boolean] autoRejoin Whether this should automatically rejoin channels it was kicked from. Default: false
	@option opt [Boolean] autoConnect Whether this should automatically connect after being created or not. Default: true
	@option opt [Boolean] autoSplitMessage Whether this should automatically split outgoing messages. Default: true
	@option opt [Integer] messageDelay How long to throttle between outgoing messages. Default: 1000

	###
	constructor: (opt) ->
		@_ =
			numRetries: 0
			connected: false
			disconnecting: false
			messageQueue: []
			channels: {}
			iSupport: {}
			greeting: {}
			# default values in case there's no iSupport
			prefix:
				o: "@"
				v: "+"
			chanmodes: ["beI", "k", "l", "aimnpqsrt"]
		if not opt?
			throw new Error "No options argument given."
		if typeof opt is "string"
			opt = require path.resolve opt
		@opt = {}
		@opt[key] = value for key, value of defaultOpt
		@opt[key] = value for key, value of opt
		if not @opt.server?
			throw new Error "No server specified."
		if @opt.autoConnect
			@connect()

	###
	Logs to console if verbose is enabled.
	@nodoc
	@param msg [String] String to log
	###
	log: (msg) -> console.log msg if @opt.verbose

	###
	Connects to the server.
	@param cb [Function] Optional callback to be called on "connect" event.
	###
	connect: (cb) ->
		@log "Connecting..."
		@conn = net.connect @opt.port, @opt.server, =>
			if cb instanceof Function
				@once "connect", (nick) ->
					cb(nick)
			@log "Connected"
			@conn.on "data", (data) =>
				@log data.toString()
				for line in data.toString().split "\r\n"
					@handleReply line
			@conn.on "close", =>
				@conn.destroy()
				@conn = null
				@_.connected = false

			@raw "PASS #{@opt.password}", false if @opt.password?
			@raw "NICK #{@opt.nick}", false
			@raw "USER #{@opt.username} 8 * :#{@opt.realname}", false

	###
	@overload #disconnect()
	  Disconnects from the server.
	@overload #disconnect(reason)
	  Disconnects from the server.
	  @param reason [String] The quit reason.
	@overload #disconnect(cb)
	  Disconnects from the server.
	  @param cb [Function] Callback to call on successful disconnect.
	@overload #disconnect(reason, cb)
	  Disconnects from the server.
	  @param reason [String] The quit reason.
	  @param cb [Function] Callback to call on successful disconnect.
	###
	disconnect: (reason, cb) ->
		if reason instanceof Function
			cb = reason
			reason = undefined
		@_.disconnecting = true
		if reason?
			@raw "QUIT :#{reason}", false
		else
			@raw "QUIT", false
		if cb instanceof Function
			@once "disconnect", ->
				cb()


	###
	Sends a raw message to the server. Automatically appends "\r\n".
	@param msg [String] The raw message to send.
	@param delay [Boolean] If false, the message skips the message queue and is sent right away. Defaults to true.
	###
	raw: (msg, delay = true) ->
		if not delay or @opt.messageDelay is 0
			@log "-> #{msg}"
			@conn.write msg + "\r\n"
		else
			setTimeout @dequeue, 0 if @_.messageQueue.length is 0
			@_.messageQueue.push msg
		
	###
	@nodoc
	Sends a raw message on the message queue
	###
	dequeue: () =>
		msg = @_.messageQueue.shift()
		@log "-> #{msg}"
		@conn.write msg + "\r\n"
		setTimeout @dequeue, @opt.messageDelay if @_.messageQueue.length isnt 0

	###
	Sends a message (PRIVMSG) to the target.
	@param target [String] The target to send the message to. Can be user or channel or whatever else the IRC specification allows.
	@param msg [String] The message to send.
	###
	msg: (target, msg) ->
		@raw "PRIVMSG #{target} :#{msg}"

	###
	Sends an action to the target.
	@param target [String] The target to send the message to. Can be user or channel or whatever else the IRC specification allows.
	@param msg [String] The action to send.
	###
	action: (target, msg) ->
		@msg target, "\u0001ACTION #{msg}\u0001"

	###
	Sends a notice to the target.
	@param target [String] The target to send the notice to. Can be user or channel or whatever else the IRC specification allows.
	@param msg [String] The message to send.
	###
	notice: (target, msg) ->
		@raw "NOTICE #{target} :#{msg}"

	###
	@overload #nick()
	  Gets the client's current nickname.
	  @return [String] The bot's current nickname.
	
	@overload #nick(desiredNick)
	  Changes the client's nickname.
	  @param desiredNick [String] The new nickname to change to.

	@overload #nick(desiredNick, cb)
	  Changes the client's nickname, with a callback for success or failure.
	  @param desiredNick [String] The new nickname to change to.
	  @param cb [function] (err, old, new) If successful, err will be undefined, otherwise err will be the parsed message object of the error

	@todo Accept optional callback like Kurea does.
	###
	nick: (desiredNick, cb) ->
		return @_.nick if not desiredNick?
		if cb instanceof Function
			nickListener = (oldNick, newNick) ->
				if newNick is desiredNick
					removeListeners()
					cb undefined, oldNick, newNick
			errListener = (msg) ->
				if 431 <= parseInt(msg.command) <= 436 # irc errors for nicks
					removeListeners()
					cb msg

			removeListeners = =>
				@removeListener 'raw', errListener
				@removeListener 'nick', nickListener

			@on 'nick', nickListener
			@on 'raw', errListener

		@raw "NICK #{desiredNick}"

	###
	@overload #join(chan)
	  Joins a channel.

	  @param chan [String, Array] The channel or array of channels to join

	@overload #join(chan, cb)
	  Joins a channel.

	  @param chan [String, Array] The channel or array of channels to join
	  @param cb [Function] A callback that's called on successful join
	###
	join: (chan, cb) ->
		if chan instanceof Array and chan.length > 0
			@raw "JOIN #{chan.join()}"
			if cb instanceof Function
				for c in chan
					do (c) =>
						@once "join#{c}", (channel, nick) ->
							cb(channel, nick)

		else
			@raw "JOIN #{chan}"
			if cb instanceof Function
				@once "join#{chan}", (channel, nick) ->
					cb(channel, nick)

	###
	@overload #part(chan)
	  Parts a channel.

	  @param chan [String, Array] The channel or array of channels to part

	@overload #part(chan, reason)
	  Parts a channel with a reason message.

	  @param chan [String, Array] The channel or array of channels to part
	  @param reason [String] The reason message

	@overload #part(chan, cb)
	  Parts a channel.

	  @param chan [String, Array] The channel or array of channels to part
	  @param cb [Function] A callback that's called on successful part

	@overload #part(chan, reason, cb)
	  Parts a channel with a reason message.

	  @param chan [String, Array] The channel or array of channels to part
	  @param reason [String] The reason message
	  @param cb [Function] A callback that's called on successful part
	###
	part: (chan, reason, cb) ->
		reason = "" if not reason?
		if reason instanceof Function
			cb = reason
			reason = ""
		else
			reason = " :" + reason
		if chan instanceof Array and chan.length > 0
			@raw "PART #{chan.join()+reason}"
			if cb instanceof Function
				for c in chan
					do (c) =>
						@once "part#{c}", (channel, nick) ->
							cb(channel, nick)
		else
			@raw "PART #{chan+reason}"
			if cb instanceof Function
				@once "part#{chan}", (channel, nick) ->
					cb(channel, nick)

	###
	Returns if this client is connected.
	NOTE: Not just connected to the socket, but connected in the sense
	that the IRC server has accepted the connection attempt with a 001 reply
	@return [Boolean] true if connected, false otherwise
	###
	isConnected: -> return @_.connected

	###
	@overload #kick(chan, nick)
	  Kicks a user from a channel.

	  @param chan [String, Array] The channel or array of channels to kick in
	  @param nick [String, Array] The channel or array of nicks to kick

	@overload #kick(chan, nick, reason)
	  Kicks a user from a channel with a reason.

	  @param chan [String, Array] The channel or array of channels to kick in
	  @param nick [String, Array] The channel or array of nicks to kick
	  @param reason [String] The reason to give when kicking
	###
	kick: (chan, user, reason) ->
		chan = chan.join() if chan instanceof Array
		user = user.join() if user instanceof Array
		if reason?
			reason = " :" + reason
		else
			reason = ""
		@raw "KICK #{chan} #{user}#{reason}"

	ban: (chan, hostmask) ->
		@mode chan, "+b #{hostmask}"

	unban: (chan, hostmask) ->
		@mode chan, "-b #{hostmask}"

	mode: (chan, modeStr) ->
		return getChannel(chan).mode() if not modeStr?
		@raw "MODE #{chan} #{modeStr}"

	op: (chan, user) ->
		@mode chan, "+o #{user}"

	deop: (chan, user) ->
		@mode chan, "-o #{user}"

	voice: (chan, user) ->
		@mode chan, "+v #{user}"

	devoice: (chan, user) ->
		@mode chan, "-v #{user}"

	###
	Invites a user to a channel.
	@param nick [String] The user to invite
	@param chan [String] The channel to invite the user to
	###
	invite: (nick, chan) ->
		@raw "INVITE #{nick} #{chan}"

	###
	@overload #verbose()
	  Getter for "verbose" in options.
	  @return [Boolean] the value of verbose
	@overload #verbose(value)
	  Setter for "verbose"
	  @param value [Boolean] The value of verbose to set
	###
	verbose: (enabled) ->
		return @opt.verbose if not enabled?
		@opt.verbose = enabled

	###
	Returns the channel objects of all channels the client is in.
	The array is a shallow copy, so modify it if you want.
	However, avoid modifying the private values in the channels themselves.
	@return [Array] The array of all channels the client is in.
	###
	channels: () ->
		return (channel for channel in @_.channels)

	###
	Gets the Channel object if the bot is in that channel.
	@param name [String] The name of the channel
	@return [Boolean] The Channel object, or undefined if the bot is not in that channel.
	###
	getChannel: (name) ->
		return @_.channels[name.toLowerCase()]

	###
	Checks if the client is in the channel.
	@param name [String] The name of the channel
	@return [Boolean] true if the bot is in the given channel.
	###
	isInChannel: (name) ->
		return getChannel(name) instanceof Channel

	isChannel: (chan) ->
		return @_.iSupport["CHANTYPES"].indexOf(chan[0]) isnt -1

	###
	@nodoc
	###
	handleReply: (reply) ->
		parsedReply = parseMessage reply
		if parsedReply?
			switch parsedReply.command
				when "JOIN"
					nick = getSender parsedReply
					chan = parsedReply.params[0]
					if nick is @nick()
						@_.channels[chan.toLowerCase()] = new Channel @, chan
					else
						@_.channels[chan.toLowerCase()]._.users[nick] = ""
					@emit "join", chan, nick
					@emit "join#{chan}", chan, nick
					# Because no one likes case sensitivity
					if chan.toLowerCase() isnt chan
						@emit "join#{chan.toLowerCase()}", chan, nick
				when "PART"
					nick = getSender parsedReply
					chan = parsedReply.params[0]
					reason = parsedReply.params[1]
					if nick is @nick()
						delete @_.channels[chan.toLowerCase()]
					else
						users = @_.channels[chan.toLowerCase()]._.users
						for user of users when user is nick
							delete users[nick]
							break
					@emit "part", chan, nick, reason
					@emit "part#{chan}", chan, nick, reason
					# Because no one likes case sensitivity
					if chan.toLowerCase() isnt chan
						@emit "part#{chan.toLowerCase()}", chan, nick
				when "NICK"
					oldnick = getSender parsedReply
					newnick = parsedReply.params[0]
					if oldnick is @nick()
						@_.nick = newnick
					@emit "nick", oldnick, newnick
				when "PRIVMSG"
					from = getSender parsedReply
					to = parsedReply.params[0]
					msg = parsedReply.params[1]
					if msg.lastIndexOf("\u0001ACTION", 0) is 0 # startsWith
						@emit "action", from, to, msg.substring(8, msg.length-1)
					else
						@emit "msg", from, to, msg
				when "NOTICE"
					from = getSender parsedReply
					to = parsedReply.params[0]
					msg = parsedReply.params[1]
					@emit "notice", from, to, msg
				when "INVITE"
					from = getSender parsedReply
					# don't need to because you don't get invites for other ppl
					chan = parsedReply.params[1]
					@emit "invite", from, chan
				when "KICK"
					kicker = getSender parsedReply
					chan = parsedReply.params[0]
					nick = parsedReply.params[1]
					reason = parsedReply.params[2]
					if nick is @nick()
						delete @_.channels[chan.toLowerCase()]
					else
						users = @_.channels[chan.toLowerCase()]._.users
						for user of users when user is nick
							delete users[nick]
							break
					@emit "kick", chan, nick, kicker, reason
				when "MODE"
					sender = getSender parsedReply
					chan = parsedReply.params[0]
					user = chan if not @isChannel(chan)
					modes = parsedReply.params[1]
					params = parsedReply.params[2..] if parsedReply.params.length > 2
					adding = true
					for c in modes
						if c is "+"
							adding = true
							continue
						if c is "-"
							adding = false
							continue
						if not user? # We're dealin with a real deal channel mode
							param = undefined
							# Cases where mode has param
							if @_.chanmodes[0].indexOf(c) isnt -1 or
							@_.chanmodes[1].indexOf(c) isnt -1 or
							(adding and @_.chanmodes[2].indexOf(c) isnt -1) or
							@_.prefix[c]?
								param = params.shift()
							if @_.prefix[c]? # Update user's mode in channel
								@getChannel(chan)._.users[param] = if adding then @_.prefix[c] else ""
							else # Update channel mode
								channelModes = @getChannel(chan)._.mode
								if adding
									channelModes.push c
								if not adding
									index = channelModes.indexOf c
									channelModes[index..index] = [] if index isnt -1
							@emit "+mode", chan, sender, c, param if adding
							@emit "-mode", chan, sender, c, param if not adding
						else # We're dealing with some stupid user mode
							# Ain't no one got time to keep track of user modes
							@emit "+usermode", user, c, sender if adding
							@emit "-usermode", user, c, sender if not adding


					# @emit "mode", chan, sender, mode
				when "QUIT"
					nick = getSender parsedReply
					reason = parsedReply.params[0]
					if nick is @nick() # Dunno if this ever happens.
						delete @_.channels[chan.toLowerCase()]
					else
						for name, chan of @_.channels
							for user of chan._.users when user is nick
								delete chan._.users[nick]
								break
					@emit "quit", nick, reason
				when "PING"
					@raw "PONG :#{parsedReply.params[0]}", false
				when "ERROR"
					@conn.destroy()
					@_.channels = {}
					@conn = null
					@_.connected = false
					@emit "error", parsedReply.params[0] if not @_.disconnecting
					@emit "disconnect"
					@_.disconnecting = false
					@log "Disconnected"
				when "001" # RPL_WELCOME
					@_.connected = true
					@_.nick = parsedReply.params[0]
					@emit "connect", @_.nick
					@join @opt.channels

				when "002" # RPL_YOURHOST
					@_.greeting.yourHost = parsedReply.params[1]
				when "003" # RPL_CREATED
					@_.greeting.created = parsedReply.params[1]
				when "004" # RPL_MYINFO
					@_.greeting.myInfo = parsedReply.params[1..].join " "
				when "005" # RPL_ISUPPORT because we can
					for item in parsedReply.params[1..]
						continue if item.indexOf(" ") isnt -1
						split = item.split "="
						if split.length is 1
							@_.iSupport[item] = true
						else
							@_.iSupport[split[0]] = split[1]
						switch split[0]
							when "PREFIX"
								match = /\((.+)\)(.+)/.exec(split[1])
								@_.prefix = {}
								@_.prefix[match[1][i]] = match[2][i] for i in [0...match[1].length]
								@_.reversePrefix = {}
								@_.reversePrefix[match[2][i]] = match[1][i] for i in [0...match[1].length]
							when "CHANMODES"
								@_.chanmodes = split[1].split ","
								# chanmodes[0,1] always require param
								# chanmodes[2] requires param on set
								# chanmodes[3] never require param
								
				when "331" #RPL_NOTOPIC
					@_.channels[parsedReply.params[1].toLowerCase()]._.topic = ""
				when "332" #RPL_TOPIC
					@_.channels[parsedReply.params[1].toLowerCase()]._.topic = parsedReply.params[2]
				when "333" #RPL_TOPICWHOTIME
					chan = @_.channels[parsedReply.params[1].toLowerCase()]
					chan._.topicSetter = parsedReply.params[2]
					chan._.topicTime = new Date parseInt(parsedReply.params[3])
				when "353" #RPL_NAMREPLY
					chan = @_.channels[parsedReply.params[2].toLowerCase()]
					names = parsedReply.params[3].split " "
					for name in names
						if @_.reversePrefix[name[0]]?
							chan._.users[name[1..]] = name[0]
						else
							chan._.users[name] = ""
				when "372" #RPL_MOTD
					@_.MOTD += parsedReply.params[1] + "\r\n"
				when "375" # RPL_MOTDSTART
					@_.MOTD = parsedReply.params[1] + "\r\n"
				when "376" # RPL_ENDOFMOTD
					@emit "motd", @_.MOTD

				when "433" # ERR_NICKNAMEINUSE
					if @opt.autoNickChange
						@_.numRetries++
						@nick @opt.nick + @_.numRetries
					else
						@disconnect()
		@emit "raw", parsedReply

module.exports = Client

###
Events so far

join: (chan, nick)
join#chan: (chan, nick)
part: (chan, nick, reason)
part#chan: (chan, nick, reason)
kick: (chan, nick, kicker, reason)
connect: (nick)
nick: (old, new)
raw: (parsedReply)
motd: (motd)
error: (msg)
disconnect: ()
quit: (nick, reason)
action: (from, to, msg)
msg: (from, to, msg)
notice: (from, to, msg)
invite: (from, chan)
+/-mode: (chan, sender, mode, param) (sender can be nick or server) (param depends on mode)
+/-usermode: (user, mode, sender)
###