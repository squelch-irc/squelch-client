{getSender} = require '../../util'
Promise = require 'bluebird'

module.exports = ->
	return (client) ->
		client.part = (channel, reason, cb) ->
			if not reason?
				reason = ''
			else if reason instanceof Function
				cb = reason
				reason = ''
			else
				reason = ' :' + reason
			if channel instanceof Array and channel.length > 0
				@raw "PART #{channel.join()+reason}"
				partPromises = for c in channel
					do (c) =>
						new Promise (resolve) =>
							listener = ({chan, nick}) ->
								return if chan isnt c
								client._.internalEmitter.off 'part', listener
								resolve chan
							@_.internalEmitter.on 'part', listener
				return Promise.all(partPromises).nodeify cb or @cbNoop

			else
				return new Promise (resolve) =>
					@raw "PART #{channel+reason}"
					listener = ({chan, nick}) ->
						return if chan isnt channel
						client._.internalEmitter.off 'part', listener
						resolve chan
					@_.internalEmitter.once 'part', listener
				.nodeify cb or @cbNoop
		client._.internalEmitter.on 'raw', (reply) ->
			if reply.command is 'PART'
				nick = getSender reply
				chan = reply.params[0]
				reason = reply.params[1]
				me = nick is client.nick()
				client.emit 'part', {chan, nick, reason, me}
