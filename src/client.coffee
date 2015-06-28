net = require 'net'
tls = require 'tls'
path = require 'path'
EventEmitter2 = require('eventemitter2').EventEmitter2
ircMsg = require 'irc-message'
Promise = require 'bluebird'
streamMap = require 'through2-map'
color = require 'irc-colors'

{getSender} = require './util'
{getReplyCode, getReplyName} = require './replies'

defaultOpt =
	port: 6667
	nick: "NodeIRCClient"
	username: "NodeIRCClient"
	realname: "NodeIRCClient"
	verbose: false
	verboseError: true
	channels: []
	autoNickChange: true
	autoRejoin: false
	autoConnect: true
	autoSplitMessage: true
	messageDelay: 1000
	stripColors: true
	stripStyles: true
	autoReconnect: true
	autoReconnectTries: 3
	reconnectDelay: 5000
	ssl: false
	selfSigned: false
	certificateExpired: false
	timeout: 120000

###
An IRC Client.
@author Rahat Ahmed

Client extends EventEmitter2, so you can use the typical on or once functions with the following events.
## Events
 - **connect**: *(nick)*</br>
	When the client successfully connects to the server. (Note: This is not just when the connection is made, but after the 001 welcome reply is received.)
 - **disconnect**: *()*</br>
	When the client is disconnected from the server. This happens either by error or by explicitly calling the disconnect function. If the client is explicitly disconnected, then there will NOT be an error event emitted.
 - **error**: *(msg)*</br>
	When an error occurs. This will disconnect the client and also emit a disconnect event.
 - **nick**: *(old, new)*</br>
	When someone changes their nick and is visible in a channel the client is in. Can be the client itself.
 - **join**: *(chan, nick)*</br>
	When a user joins any channel the client is in. Can be the client itself.
 - **join::chan**: *(chan, nick)*</br>
	When a user joins #chan. The client must be in #chan for this to work. Can be the client itself. If #chan has upper case letters like '#IRCHelp', it will trigger both join::#IRCHelp and join::#irchelp.
 - **part**: *(chan, nick, reason)*</br>
	When a user parts any channel the client is in. Can be the client itself.
 - **part::chan**: *(chan, nick, reason)*</br>
	When a user parts #chan. See the join::chan event above.
 - **kick**: *(chan, nick, kicker, reason)*</br>
	When a user is kicked from a channel the client is in. Reason is optional.
 - **raw**: *(parsedMsg)*</br>
	When any raw message is received. parsedMsg will be the object that the irc-message module returns from parsing the message.
 - **motd**: *(motd)*</br>
	When the server's motd is received.
 - **quit**: *(nick, reason)*</br>
	When someone quits from the server. This will not trigger for the client itself.
 - **action**: *(from, to, msg)*</br>
	When someone sends an action in a channel the client is in.
 - **msg**: *(from, to, msg)*</br>
	When someone sends a message to the client or a channel the client is in.
 - **notice**: *(from, to, msg)*</br>
	When someone sends a notice to the client.
 - **invite**: *(from, chan)*</br>
	When someone invites the client to a channel.
 - **+mode**: *(chan, setter, mode, param)*</br>
	When the mode is set in a channel. The mode parameter will only be a single mode. Param is optional, depending on the mode letter. The setter can be a nick or the server.
 - **-mode**: *(chan, setter, mode, param)*</br>
	When the mode is removed in a channel. The mode parameter will only be a single mode. Param is optional, depending on the mode letter. The setter can be a nick or the server.
 - **+usermode**: *(user, mode, setter)*</br>
	When the mode is set on a user. The mode parameter will only be a single mode. The setter can be a nick or the server.
 - **-usermode**: *(user, mode, setter)*</br>
	When the mode is removed from a user. The mode parameter will only be a single mode. The setter can be a nick or the server.
 - **timeout**: *(seconds)*</br>
	When the client times out, this event will be triggered right before disconnecting.
 - **names**: *(chan)*</br>
 	When the client finishes receiving the list of names for a channel. Chan will be '*' if you sent the NAMES command without any channel parameter, as per the RFC. You may access the updated names by getting the channel object from getChannel(chan).
###
class Client extends EventEmitter2
	###
	Constructor for Client.
	@option opt [String] server The server address to connect to
	@option opt [Integer] port The port to connect to. Default: 6667
	@option opt [String] nick The nickname to connect with. Default: NodeIRCClient
	@option opt [String] username The username to connect with. Default: NodeIRCClient
	@option opt [String] realname The real name to connect with. Default: NodeIRCClient
	@option opt [Array] channels The channels to autoconnect to on connect. Default: []
	@option opt [Boolean] verbose Whether this should output log messages to console or not. Default: false
	@option opt [Boolean] verboseError Whether this should output error messages to console or not. Default: true
	@option opt [Boolean] autoNickChange Whether this should try alternate nicks if the given one is taken, or give up and quit. Default: true
	@option opt [Boolean] autoRejoin Whether this should automatically rejoin channels it was kicked from. Default: false
	@option opt [Boolean] autoConnect Whether this should automatically connect after being created or not. Default: true
	@option opt [Boolean] autoSplitMessage Whether this should automatically split outgoing messages. Default: true NOTE: This will split the messages conservatively. Message lengths will be around 400-ish.
	@option opt [Integer] messageDelay How long to throttle between outgoing messages. Default: 1000
	@option opt [Boolean] stripColors Strips colors from incoming messages before processing. Default: true
	@option opt [Boolean] stripStyles Strips styles from incoming messages before processing, like bold and underline. Default: true
	@option opt [Integer] reconnectDelay Time in milliseconds to wait before trying to reconnect. Default: 5000
	@option opt [Boolean] autoReconnect Whether this should automatically attempt to reconnect on disconnecting from the server by error. If you explicitly call disconnect(), the client will not attempt to reconnect. This does NOT apply to the connect() retries. Default: true
	@option opt [Integer] autoReconnectTries The number of attempts to reconnect if autoReconnect is enabled. If this is -1, then the client will try infinitely many times. This does NOT apply to the connect() retries. Default: 3
	@option opt [Boolean/Object] ssl Whether to use ssl to connect to the server. If ssl is an object, then it is used as the options for ssl connections (See tls.connect in 'tls' node module). Default: false
	@option opt [Boolean] selfSigned Whether to accept self signed ssl certificates or not. Default: false
	@option opt [Boolean] certificateExpired Whether to accept expired certificates or not. Default: false
	@option opt [Integer] timeout Number of milliseconds to wait before timing out. Default: 120000

	###
	constructor: (opt) ->
		# Set EventEmitter2 options
		super
			wildcard: true
			delimiter: '::'
			newListener: false
		@setMaxListeners 0
		@_ =
			numRetries: 0
			connected: false
			disconnecting: false
			messageQueue: []
			iSupport: {}
			greeting: {}
			# default values in case there's no iSupport
			prefix:
				o: '@'
				v: '+'
			chanmodes: ['beI', 'k', 'l', 'aimnpqsrt']
		if not opt?
			throw new Error 'No options argument given.'
		if typeof opt is 'string'
			opt = require path.resolve opt
		@opt = {}
		@opt[key] = value for key, value of defaultOpt
		@opt[key] = value for key, value of opt
		if not @opt.server?
			throw new Error 'No server specified.'

		# Use core plugins
		@use require('./plugins/core/msg')()
		@use require('./plugins/core/notice')()
		@use require('./plugins/core/nick')()
		@use require('./plugins/core/join')()
		@use require('./plugins/core/part')()
		@use require('./plugins/core/kick')()
		@use require('./plugins/core/invite')()
		@use require('./plugins/core/mode')()
		@use require('./plugins/core/motd')()
		@use require('./plugins/channel')()

		if @opt.autoConnect
			@connect()

	###
	Logs to console if verbose is enabled.
	@nodoc
	@param msg [String] String to log
	###
	log: (msg) -> console.log msg if @opt.verbose

	###
	Logs to standard error if verbose is enabled.
	@nodoc
	@param msg [String] String to log
	###
	logError: (msg) -> console.error msg if @opt.verboseError

	###
	Default callback when callback isn't specified to a function.
	By default it will log the error to console if this bot is
	@nodoc
	@param err [Error] The Error that this callback receives.
	###
	cbNoop: (err) => @logError err if err


	###
	@overload #connect()
	  Connects to the server.
	  @return [Promise<String,Error>] A promise that is resolves with the nick on successful disconnect, and rejects with an Error on connection error.
	@overload #connect(tries)
	  Connects to the server.
	  @param tries [Integer] Number of times to retry connecting. If -1, the client will try to connect infinitely many times.
	  @return [Promise<String,Error>] A promise that is resolves with the nick on successful disconnect, and rejects with an Error on connection error.
	@overload #connect(cb)
	  Connects to the server.
	  @param cb [Function] Optional callback to be called on 'connect' event.
	  @return [Promise<String,Error>] A promise that is resolves with the nick on successful disconnect, and rejects with an Error on connection error.
	@overload #connect(tries, cb)
	  Connects to the server.
	  @param tries [Integer] Number of times to retry connecting. If -1, the client will try to connect infinitely many times.
	  @param cb [Function] Optional callback to be called on 'connect' event.
	  @return [Promise<String,Error>] A promise that is resolves with the nick on successful disconnect, and rejects with an Error on connection error.
	###
	connect: (tries = 1, cb) ->
		return new Promise (resolve, reject) =>
			@log 'Connecting...'
			if tries instanceof Function
				cb = tries
				tries = 1
			tries--

			errorListener = (err) =>
				@logError 'Unable to connect.'
				@logError err
				if tries > 0 or tries is -1
					@logError "Reconnecting in #{@opt.reconnectDelay/1000} seconds... (#{tries} remaining tries)"
					setTimeout =>
						@connect tries, cb
					, @opt.reconnectDelay
				else
					reject err
			onConnect = =>
				@conn.setEncoding 'utf8'
				@conn.removeListener 'error', errorListener
				@once 'connect', (nick) ->
					resolve nick
				@log 'Connected'
				stream = @conn
				if @opt.stripColors
					stream = stream.pipe streamMap wantStrings: true, color.stripColors
				if @opt.stripStyles
					stream = stream.pipe streamMap wantStrings: true, color.stripStyle
				stream = stream.pipe ircMsg.createStream parsePrefix: true
				stream.on 'data', (data) =>
					clearTimeout @_.timeout if @_.timeout
					@_.timeout = setTimeout =>
						@raw 'PING :ruthere'
						pingTime = new Date().getTime()
						@_.timeout = setTimeout =>
							seconds = (new Date().getTime() - pingTime) / 1000
							@emit 'timeout', seconds
							@handleReply ircMsg.parse "ERROR :Ping Timeout(#{seconds} seconds)"
						, @opt.timeout
					, @opt.timeout
					if data?
						@handleReply data
						@emit 'raw', data

				@conn.on 'error', (e) =>
					@logError 'Disconnected by network error.'
					if @opt.autoReconnect and @opt.autoReconnectTries > 0
						@log "Reconnecting in #{@opt.reconnectDelay/1000} seconds... (#{@opt.autoReconnectTries} remaining tries)"
						setTimeout =>
							@connect @opt.autoReconnectTries
						, @opt.reconnectDelay
				@raw "PASS #{@opt.password}", false if @opt.password?
				@raw "NICK #{@opt.nick}", false
				@raw "USER #{@opt.username} 8 * :#{@opt.realname}", false
			if @opt.ssl
				tlsOptions = if @opt.ssl instanceof Object then @opt.ssl else {}
				tlsOptions.rejectUnauthorized = false if @opt.selfSigned
				@conn = tls.connect @opt.port, @opt.server, tlsOptions, =>
					if not @conn.authorized
						if @opt.selfSigned and (@conn.authorizationError is 'DEPTH_ZERO_SELF_SIGNED_CERT' or
											@conn.authorizationError is 'UNABLE_TO_VERIFY_LEAF_SIGNATURE' or
											@conn.authorizationError is 'SELF_SIGNED_CERT_IN_CHAIN')
							@log 'Connecting to server with self signed certificate'
						else if @opt.certificateExpired and @conn.authorizationError is 'CERT_HAS_EXPIRED'
							@log 'Connecting to server with expired certificate'
						else
							@log "Authorization error: #{@conn.authorizationError}"
							return
					onConnect()
			else
				@conn = net.connect @opt.port, @opt.server, onConnect
			@conn.once 'error', errorListener
		.nodeify cb or @cbNoop

	###
	@overload #disconnect()
	  Disconnects from the server.
	  @return [Promise<>] A promise that is resolved on successful disconnect.
	@overload #disconnect(reason)
	  Disconnects from the server.
	  @param reason [String] The quit reason.
	  @return [Promise<>] A promise that is resolved on successful disconnect.
	@overload #disconnect(cb)
	  Disconnects from the server.
	  @param cb [Function] Callback to call on successful disconnect.
	  @return [Promise<>] A promise that is resolved on successful disconnect.
	@overload #disconnect(reason, cb)
	  Disconnects from the server.
	  @param reason [String] The quit reason.
	  @param cb [Function] Callback to call on successful disconnect.
	  @return [Promise<>] A promise that is resolved on successful disconnect.
	###
	disconnect: (reason, cb) ->
		return new Promise (resolve) =>
			if reason instanceof Function
				cb = reason
				reason = undefined
			@_.disconnecting = true
			if reason?
				@raw "QUIT :#{reason}", false
			else
				@raw 'QUIT', false
			@once 'disconnect', ->
				resolve()
		.nodeify cb or @cbNoop

	###
	@overload #forceQuit()
	  Immediately disconnects from the server without waiting for the server to acknowledge the QUIT request.
	@overload #forceQuit(reason)
	  Immediately disconnects from the server with a reason without waiting for the server to acknowledge the QUIT request.
	  @param reason [String] The quit reason.
	###
	forceQuit: (reason) ->
		@raw 'QUIT' + (if reason? then " :#{reason}" else ''), false
		@_.disconnecting = true
		@handleReply ircMsg.parse 'ERROR :Force Quit'

	###
	Sends a raw message to the server. Automatically appends '\r\n'.
	@param msg [String] The raw message to send.
	@param delay [Boolean] If false, the message skips the message queue and is sent right away. Defaults to true.
	###
	raw: (msg, delay = true) ->
		if not msg?
			throw new Error()
		if not @conn?
			return
		if not delay or @opt.messageDelay is 0
			@log "-> #{msg}"
			@conn.write msg + '\r\n'
		else
			setTimeout @dequeue, 0 if @_.messageQueue.length is 0
			@_.messageQueue.push msg
		
	###
	@nodoc
	Sends a raw message on the message queue
	###
	dequeue: () =>
		msg = @_.messageQueue.shift()
		if @conn?
			@log "-> #{msg}"
			@conn.write msg + '\r\n'
		@_.messageQueueTimeout = setTimeout @dequeue, @opt.messageDelay if @_.messageQueue.length isnt 0

	###
	@nodoc
	Splits message into array of safely sized chunks
	Include the target in the command
	###
	splitText: (command, msg, extra = 0) ->
		limit = 512 -
			3 - 					# :!@
			@_.nick.length - 		# nick of hostmask
			9 - 					# max username
			65 - 					# max hostname
			command.length - 		# command
			2 - 					# ' :' before msg
			2 -						# /r/n
			extra					# any extra space requested
		return (msg.slice(i, i+limit) for i in [0..msg.length] by limit)
			
	###
	Registers a plugin with this client.
	@param plugin [Function] A function that accepts this client as an argument
	###
	use: (plugin) -> plugin @

	###
	Returns if this client is connected.
	NOTE: Not just connected to the socket, but connected in the sense
	that the IRC server has accepted the connection attempt with a 001 reply
	@return [Boolean] true if connected, false otherwise
	###
	isConnected: -> return @_.connected

	###
	@overload #verbose()
	  Getter for 'verbose' in options.
	  @return [Boolean] the value of verbose
	@overload #verbose(enabled)
	  Setter for 'verbose'
	  @param enabled [Boolean] The value of verbose to set
	###
	verbose: (enabled) ->
		return @opt.verbose if not enabled?
		@opt.verbose = enabled

	###
	@overload #verboseError()
	  Getter for 'verboseError' in options.
	  @return [Boolean] the value of verboseError
	@overload #verboseError(enabled)
	  Setter for 'verboseError'
	  @param enabled [Boolean] The value of verboseError to set
	###
	verboseError: (enabled) ->
		return @opt.verboseError if not enabled?
		@opt.verboseError = enabled

	###
	@overload #messageDelay()
	  Getter for 'messageDelay' in options.
	  @return [Boolean] the value of messageDelay
	@overload #messageDelay(value)
	  Setter for 'messageDelay'
	  @param value [Boolean] The value of messageDelay to set
	###
	messageDelay: (value) ->
		return @opt.messageDelay if not value?
		@opt.messageDelay = value

	###
	@overload #autoSplitMessage()
	  Getter for 'autoSplitMessage' in options.
	  @return [Boolean] the value of autoSplitMessage
	@overload #autoSplitMessage(enabled)
	  Setter for 'autoSplitMessage'
	  @param enabled [Boolean] The value of autoSplitMessage to set
	###
	autoSplitMessage: (enabled) ->
		return @opt.autoSplitMessage if not enabled?
		@opt.autoSplitMessage = enabled

	###
	@overload #autoRejoin()
	  Getter for 'autoRejoin' in options.
	  @return [Boolean] the value of autoRejoin
	@overload #autoRejoin(enabled)
	  Setter for 'autoRejoin'
	  @param enabled [Boolean] The value of autoRejoin to set
	###
	autoRejoin: (enabled) ->
		return @opt.autoRejoin if not enabled?
		@opt.autoRejoin = enabled

	###
	Checks if a string represents a channel, based on the CHANTYPES value
	from the server's iSupport 005 response. Typically this means it checks
	if the string starts with a '#'.
	@param chan [String] The string to check
	@return [Boolean] true if chan starts with a valid channel prefix (ex: #), false otherwise
	###
	isChannel: (chan) ->
		return @_.iSupport['CHANTYPES'].indexOf(chan[0]) isnt -1

	###
	@nodoc
	###
	handleReply: (parsedReply) ->
		if not parsedReply?
			return
		@log '<-' + parsedReply.raw
		switch parsedReply.command
			when 'QUIT'
				nick = getSender parsedReply
				reason = parsedReply.params[0]
				for name, chan of @_.channels
					for user of chan._.users when user is nick
						delete chan._.users[nick]
						break
				@emit 'quit', nick, reason
			when 'PING'
				@raw "PONG :#{parsedReply.params[0]}", false
			when 'ERROR'
				@conn.destroy()
				@_.channels = {}
				@_.messageQueue = []
				clearTimeout @_.messageQueueTimeout
				clearTimeout @_.timeout
				@conn = null
				@_.connected = false
				@emit 'error', parsedReply.params[0] if not @_.disconnecting
				@_.disconnecting = false
				@emit 'disconnect'
				@log 'Disconnected from server'
				if @opt.autoReconnect and @opt.autoReconnectTries > 0
					@log "Reconnecting in #{@opt.reconnectDelay/1000} seconds... (#{@opt.autoReconnectTries} remaining tries)"
					setTimeout =>
						@connect @opt.autoReconnectTries
					, @opt.reconnectDelay
			when getReplyCode 'RPL_WELCOME'
				@_.connected = true
				@_.nick = parsedReply.params[0]
				@emit 'connect', @_.nick
				@join @opt.channels

			when getReplyCode 'RPL_YOURHOST'
				@_.greeting.yourHost = parsedReply.params[1]
			when getReplyCode 'RPL_CREATED'
				@_.greeting.created = parsedReply.params[1]
			when getReplyCode 'RPL_MYINFO'
				@_.greeting.myInfo = parsedReply.params[1..].join ' '
			when getReplyCode 'RPL_ISUPPORT'
				for item in parsedReply.params[1..]
					continue if item.indexOf(' ') isnt -1
					split = item.split '='
					if split.length is 1
						@_.iSupport[item] = true
					else
						@_.iSupport[split[0]] = split[1]
					switch split[0]
						when 'PREFIX'
							match = /\((.+)\)(.+)/.exec(split[1])
							@_.prefix = {}
							@_.prefix[match[1][i]] = match[2][i] for i in [0...match[1].length]
							@_.reversePrefix = {}
							@_.reversePrefix[match[2][i]] = match[1][i] for i in [0...match[1].length]
						when 'CHANMODES'
							@_.chanmodes = split[1].split ','
							# chanmodes[0,1] always require param
							# chanmodes[2] requires param on set
							# chanmodes[3] never require param

module.exports = Client
