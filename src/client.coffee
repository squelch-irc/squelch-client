net = require "net"
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

class Client
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

	log: (msg) -> console.log msg if @opt.verbose

	connect: () ->
		@log "Connecting..."
		@conn = net.connect @opt.port, @opt.server, =>
			@log "Connected"
			@conn.on "data", (data) =>
				@log data.toString()
				for line in data.toString().split "\r\n"
					@handleReply line

			@raw "PASS #{@opt.password}" if @opt.password?
			@raw "NICK #{@opt.nick}"
			@raw "USER #{@opt.username} 8 * :#{@opt.realname}"

	disconnect: (reason = "Brought to you by node-irc-client.") ->
		@raw "QUIT :#{reason}"
		@conn

	raw: (msg) ->
		@log "-> #{msg}"
		@conn.write msg + "\r\n"

	nick: (newNick) ->
		if newNick?
			@raw "NICK #{newNick}"
		else
			return @_.nick

	# TODO: accept callback to call on successful join
	join: (chan) ->
		if chan instanceof Array
			@raw "JOIN #{chan.join()}" if chan.length > 0
		else
			@raw "JOIN #{chan}"

	handleReply: (reply) ->
		parsedReply = parseMessage reply
		if parsedReply?
			switch parsedReply.command
				when "001" # RPL_WELCOME
					@join @opt.channels
					@_.nick = parsedReply.params[0]

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
					# TODO: trigger motd event

				when "433" # ERR_NICKNAMEINUSE
					if @opt.autoNickChange
						@_.numRetries++
						@nick @opt.nick + @_.numRetries
					else
						@disconnect()
				when "PING"
					@raw "PONG :#{parsedReply.params[0]}"

module.exports = Client