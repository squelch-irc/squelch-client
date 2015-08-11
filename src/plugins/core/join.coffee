{getSender} = require '../../util'
Promise = require 'bluebird'

module.exports = ->
	return (client) ->
		client.join = (channel, cb) ->
			if channel instanceof Array
				if channel.length is 0
					return
				@raw "JOIN #{channel.join()}"
				joinPromises = for c in channel
					do (c) =>
						new Promise (resolve) =>
							listener = ({chan, nick}) =>
								return if chan isnt c
								client._.internalEmitter.off 'join', listener
								resolve chan
							@_.internalEmitter.on 'join', listener
				return Promise.all(joinPromises).nodeify cb or @cbNoop

			else
				return new Promise (resolve) =>
					@raw "JOIN #{channel}"
					listener = ({chan, nick}) =>
						return if chan isnt channel
						client._.internalEmitter.off 'join', listener
						resolve chan
					@_.internalEmitter.on 'join', listener
				.nodeify cb or @cbNoop

		client._.internalEmitter.on 'raw', (reply) ->
			if reply.command is 'JOIN'
				nick = getSender reply
				chan = reply.params[0]
				me = nick is client.nick()
				client.emit 'join', {chan, nick, me}
