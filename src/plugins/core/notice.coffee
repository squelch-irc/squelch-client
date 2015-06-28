{getSender} = require '../../util'
module.exports = ->
	return (client) ->

		###
		Sends a notice to the target.
		@param target [String] The target to send the notice to. Can be user or channel or whatever else the IRC specification allows.
		@param msg [String] The message to send.
		###
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