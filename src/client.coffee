net = require "net"
path = require "path"
EventEmitter = require('events').EventEmitter
parseMessage = require "irc-message"

defaultOpt =
	port: 6667
	nick: "NodeIRCClient"
	username: "NodeIRCClient"
	realname: "NodeIRCClient"
	verbose: true
	channels: []
	autoNickChange: true
	autoRejoin: false		#
	autoConnect: true
	autoSplitMessage: true	#
	messageDelay: 1000		#

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
			iSupport: {}
			greeting: {}
			receivingMOTD: false
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
			@once "connect", (nick) ->
				cb(nick)
			@log "Connected"
			@conn.on "data", (data) =>
				@log data.toString()
				for line in data.toString().split "\r\n"
					@handleReply line

			@raw "PASS #{@opt.password}" if @opt.password?
			@raw "NICK #{@opt.nick}"
			@raw "USER #{@opt.username} 8 * :#{@opt.realname}"

	###
	Disconnects from the server.
	@param reason [String] The optional quit reason. Default is "Brought to you by node-irc-client."
	###
	disconnect: (reason = "Brought to you by node-irc-client.") ->
		@raw "QUIT :#{reason}"
		@conn = null

	###
	Sends a raw message to the server. Automatically appends "\r\n".
	@param msg [String] The raw message to send.
	###
	raw: (msg) ->
		@log "-> #{msg}"
		@conn.write msg + "\r\n"

	###
	@overload #nick()
	  Gets the client's current nickname.
	  @return [String] The bot's current nickname.
	
	@overload #nick(desiredNick)
	  Changes the client's nickname.
	  @param desiredNick [String] The new nickname to change to.

	@todo Accept optional callback like Kurea does.
	###
	nick: (desiredNick) ->
		if desiredNick?
			@raw "NICK #{desiredNick}"
		else
			return @_.nick

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
		if chan instanceof Array
			@raw "JOIN #{chan.join()}" if chan.length > 0
			if cb instanceof Function
				for c in chan
					do (c) =>
						@once "join#{c}", ->
							cb(c)

		else
			@raw "JOIN #{chan}"
			if cb instanceof Function
					@once "join#{chan}", ->
						cb(chan)
	###
	@nodoc
	###
	handleReply: (reply) ->
		parsedReply = parseMessage reply
		if parsedReply?
			switch parsedReply.command
				when "JOIN"
					nick = parsedReply.parseHostmaskFromPrefix().nickname
					chan = parsedReply.params[0]
					@emit "join", chan, nick
					@emit "join#{chan}", chan, nick
					# Because no one likes case sensitivity
					if chan.toLowerCase() isnt chan
						@emit "join#{chan.toLowerCase()}", chan, nick
				when "NICK"
					oldNick = parsedReply.parseHostmaskFromPrefix().nickname
					newNick = parsedReply.params[0]
					if oldnick is @nick()
						@_.nick = newNick
					@emit "nick", oldNick, newNick

				when "PING"
					@raw "PONG :#{parsedReply.params[0]}"
				when "001" # RPL_WELCOME
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

				when "372" #RPL_MOTD
					@_.MOTD += parsedReply.params[1] + "\r\n"
				when "375" # RPL_MOTDSTART
					@_.receivingMOTD = true
					@_.MOTD = ""
				when "376" # RPL_ENDOFMOTD
					@_.receivingMOTD = false
					@emit "motd", @_.MOTD

				when "433" # ERR_NICKNAMEINUSE
					if @opt.autoNickChange
						@_.numRetries++
						@nick @opt.nick + @_.numRetries
					else
						@disconnect()
		@emit "raw", parsedReply
	# emit: (args...) ->
	# 	@log "!! Emitting #{args}"
	# 	super args...

module.exports = Client

###
Events so far

join: (chan, nick)
join#chan: (chan, nick)
connect: (nick)
nick: (old, new)
raw: (parsedReply)
motd: (motd)
###