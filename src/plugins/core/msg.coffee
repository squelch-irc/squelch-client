{getSender} = require '../../util'
module.exports = ->
	return (client) ->
		client.msg = (target, msg) ->
			if @opt.autoSplitMessage
				for line in @splitText "PRIVMSG #{target}", msg
					@raw "PRIVMSG #{target} :#{line}"
					if @opt.triggerEventsForOwnMessages
						@emit 'msg', {from: @nick(), to: target, msg: line}
			else
				@raw "PRIVMSG #{target} :#{msg}"
				if @opt.triggerEventsForOwnMessages
					@emit 'msg', {from: @nick(), to: target, msg}


		client.action = (target, msg) ->
			if @opt.autoSplitMessage
				for line in @splitText 'PRIVMSG #{target}', msg, 9
					@msg target, "\x01ACTION #{line}\x01"
					if @opt.triggerEventsForOwnMessages
						@emit 'action', {from: @nick(), to: target, msg: line}
			else
				@msg target, "\x01ACTION #{msg}\x01"
				if @opt.triggerEventsForOwnMessages
					@emit 'action', {from: @nick(), to: target, msg}

		client._.internalEmitter.on 'raw', (reply) ->
			if reply.command is 'PRIVMSG'
				from = getSender reply
				to = reply.params[0]
				msg = reply.params[1]
				if msg.lastIndexOf('\u0001ACTION', 0) is 0 # startsWith
					client.emit 'action', {from, to, msg: msg.substring(8, msg.length-1)}
				else
					client.emit 'msg', {from, to, msg}
