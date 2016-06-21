net = require 'net'
tls = require 'tls'
path = require 'path'
{Emitter} = require '@rahatarmanahmed/event-kit'
ircMsg = require 'irc-message'
Promise = require 'bluebird'
streamMap = require 'through2-map'
color = require 'irc-colors'

debug = require('debug')('squelch-client')
debugError = require('debug')('squelch-client:error')

{getSender} = require './util'
{getReplyCode, getReplyName} = require './replies'

defaultOpt =
	port: 6667
	nick: 'NodeIRCClient'
	username: 'NodeIRCClient'
	realname: 'NodeIRCClient'
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
	triggerEventsForOwnMessages: false

class Client extends Emitter
	constructor: (opt) ->
		super()
		@_ =
			internalEmitter: new Emitter()
			numRetries: 0
			connected: false
			disconnecting: false
			messageQueue: []
			iSupport:
				CHANTYPES: '&#'
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
		@use require('./plugins/core/topic')()

		if @opt.autoConnect
			@connect()

	# Emits to internalEmitter first, then the client itself.
	# This is to give core plugin listeners priority over
	# external listeners.
	# NOTE: internalEmitter won't receive error events
	emit: (args...) ->
		@_.internalEmitter.emit args... if args[0] isnt 'error'
		super args...

	# Default callback when callback isn't specified to a function.
	# By default it will log the error to console if this bot is
	cbNoop: (err) -> debugError err if err

	connect: (tries = 1, cb) ->
		return new Promise (resolve, reject) =>
			@emit 'connecting',
				port: @opt.port
				server: @opt.server
			debug 'Connecting...'
			if tries instanceof Function
				cb = tries
				tries = 1
			tries--

			errorListener = (err) =>
				debugError 'Unable to connect.'
				debugError err
				if tries > 0 or tries is -1
					@emit 'reconnecting',
						port: @opt.port
						server: @opt.server
						delay: @opt.reconnectDelay
						triesLeft: tries
					debugError "Reconnecting in #{@opt.reconnectDelay/1000} seconds... (#{tries} remaining tries)"
					setTimeout =>
						@connect tries, cb
					, @opt.reconnectDelay
				else
					reject err
			onConnect = =>
				@conn.setEncoding 'utf8'
				@conn.removeListener 'error', errorListener
				@_.internalEmitter.once 'connect', ({nick}) ->
					resolve {nick}
				debug 'Connected'
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
							@emit 'timeout', {seconds}
							@handleReply ircMsg.parse "ERROR :Ping Timeout (#{seconds} seconds)"
						, @opt.timeout
					, @opt.timeout
					if data?
						@handleReply data
						@emit 'raw', data

				@conn.on 'error', (e) =>
					debugError 'Disconnected by network error.'
					@handleReply ircMsg.parse "ERROR :Connection error (#{e.message})"
					if @opt.autoReconnect and @opt.autoReconnectTries > 0
						debug "Reconnecting in #{@opt.reconnectDelay/1000} seconds... (#{@opt.autoReconnectTries} remaining tries)"
						setTimeout =>
							@connect @opt.autoReconnectTries
						, @opt.reconnectDelay

				@emit 'connection-established',
					port: @opt.port
					server: @opt.server

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
							debug 'Connecting to server with self signed certificate'
						else if @opt.certificateExpired and @conn.authorizationError is 'CERT_HAS_EXPIRED'
							debug 'Connecting to server with expired certificate'
						else
							debug "Authorization error: #{@conn.authorizationError}"
							return
					onConnect()
			else
				@conn = net.connect @opt.port, @opt.server, onConnect
			@conn.once 'error', errorListener
		.nodeify cb or @cbNoop

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
			@_.internalEmitter.once 'disconnect', ->
				resolve()
		.nodeify cb or @cbNoop

	forceQuit: (reason) ->
		if @isConnected()
			@raw 'QUIT' + (if reason? then " :#{reason}" else ''), false
			@_.disconnecting = true
			@handleReply ircMsg.parse 'ERROR :Force Quit'
		else if @conn?
			@conn.destroy()
			@conn = null

	raw: (msg, delay = true) ->
		if not msg?
			throw new Error()
		if not @conn?
			return
		if not delay or @opt.messageDelay is 0
			debug "-> #{msg}"
			@conn.write msg + '\r\n'
		else
			setTimeout @dequeue, 0 if @_.messageQueue.length is 0
			@_.messageQueue.push msg

	# Sends a raw message on the message queue
	dequeue: () =>
		msg = @_.messageQueue.shift()
		if @conn?
			debug "-> #{msg}"
			@conn.write msg + '\r\n'
		@_.messageQueueTimeout = setTimeout @dequeue, @opt.messageDelay if @_.messageQueue.length isnt 0

	# Splits message into array of safely sized chunks
	# Include the target in the command
	splitText: (command, msg, extra = 0) ->
		limit = 512 -
			3 -                     # :!@
			@_.nick.length -        # nick of hostmask
			9 -                     # max username
			65 -                    # max hostname
			command.length -        # command
			2 -                     # ' :' before msg
			2 -                     # /r/n
			extra                   # any extra space requested
		return (msg.slice(i, i+limit) for i in [0..msg.length] by limit)

	use: (plugin) ->
		plugin @
		@


	isConnected: -> return @_.connected

	messageDelay: (value) ->
		return @opt.messageDelay if not value?
		@opt.messageDelay = value

	autoSplitMessage: (enabled) ->
		return @opt.autoSplitMessage if not enabled?
		@opt.autoSplitMessage = enabled

	autoRejoin: (enabled) ->
		return @opt.autoRejoin if not enabled?
		@opt.autoRejoin = enabled

	triggerEventsForOwnMessages: (enabled) ->
		return @opt.triggerEventsForOwnMessages if not enabled?
		@opt.triggerEventsForOwnMessages = enabled

	isChannel: (chan) ->
		return false if not chan?
		return @_.iSupport['CHANTYPES'].indexOf(chan[0]) isnt -1

	modeToPrefix: (mode) -> return @_.prefix[mode]

	handleReply: (parsedReply) ->
		if not parsedReply?
			return
		debug '<-' + parsedReply.raw
		switch parsedReply.command
			when 'QUIT'
				nick = getSender parsedReply
				reason = parsedReply.params[0]
				@emit 'quit', {nick, reason}
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
				@emit 'error', parsedReply if not @_.disconnecting
				debug 'Disconnected from server'
				if not @_.disconnecting and @opt.autoReconnect and @opt.autoReconnectTries > 0
					debug "Reconnecting in #{@opt.reconnectDelay/1000} seconds... (#{@opt.autoReconnectTries} remaining tries)"
					setTimeout =>
						@connect @opt.autoReconnectTries
					, @opt.reconnectDelay
				@_.disconnecting = false
				@emit 'disconnect', {}
			when getReplyCode 'RPL_WELCOME'
				@_.connected = true
				@_.nick = parsedReply.params[0]
				@emit 'connect',
					nick: @_.nick
					server: @opt.server
					port: @opt.port
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
