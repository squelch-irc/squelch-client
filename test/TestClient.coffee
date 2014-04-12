Client = require '../src/client'

class TestClient extends Client
	constructor: (opt) ->
		self = @
		opt.autoConnect = false
		opt.messageDelay = 0
		super opt
		@rawLog = []
		@conn =
			write: (data) -> self.rawLog.push data
			destroy: ->
		# Checks output log to see if the client ever sent the given line
		# If param is array, returns true if all lines are in the log
		@happened = (rawLine) ->
			if rawLine instanceof Array
				(return false if not @happened line) for line in rawLine
				return true
			rawLine += "\r\n"
			return true if line is rawLine for line in @rawLog
			return false
		@handleReplies = (replies) ->
			for reply in replies
				@handleReply reply

module.exports = TestClient