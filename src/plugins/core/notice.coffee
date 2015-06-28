{getSender} = require '../../util'
module.exports = ->
	return (client) ->
		client.notice = (target, msg) ->
			if @opt.autoSplitMessage
				@raw "NOTICE #{target} :#{line}" for line in @splitText "NOTICE #{target}", msg
			else
				@raw "NOTICE #{target} :#{msg}"

		client.on 'raw', (reply) ->
			if reply.command is 'NOTICE'
				from = getSender reply
				to = reply.params[0]
				msg = reply.params[1]
				@emit 'notice', from, to, msg