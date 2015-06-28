{getSender} = require '../../util'
module.exports = ->
	return (client) ->
		client.msg = (target, msg) ->
			if @opt.autoSplitMessage
				@raw "PRIVMSG #{target} :#{line}" for line in @splitText "PRIVMSG #{target}", msg
			else
				@raw "PRIVMSG #{target} :#{msg}"

		client.action = (target, msg) ->
			if @opt.autoSplitMessage
				@msg target, "\x01ACTION #{line}\x01" for line in @splitText 'PRIVMSG #{target}', msg, 9
			else
				@msg target, "\x01ACTION #{msg}\x01"

		client.on 'raw', (reply) ->
			if reply.command is 'PRIVMSG'
				from = getSender reply
				to = reply.params[0]
				msg = reply.params[1]
				if msg.lastIndexOf('\u0001ACTION', 0) is 0 # startsWith
					@emit 'action', from, to, msg.substring(8, msg.length-1)
				else
					@emit 'msg', from, to, msg