{getSender} = require '../../util'
module.exports = ->
	return (client) ->
		client.notice = (target, msg) ->
			if @opt.autoSplitMessage
				for line in @splitText "NOTICE #{target}", msg
					@raw "NOTICE #{target} :#{line}"
					if @opt.triggerEventsForOwnMessages
						@emit 'notice', {from: @nick(), to: target, msg: line}
			else
				@raw "NOTICE #{target} :#{msg}"
				if @opt.triggerEventsForOwnMessages
					@emit 'notice', {from: @nick(), to: target, msg}

		client._.internalEmitter.on 'raw', (reply) ->
			if reply.command is 'NOTICE'
				from = getSender reply
				to = reply.params[0]
				msg = reply.params[1]
				client.emit 'notice', {from, to, msg}
