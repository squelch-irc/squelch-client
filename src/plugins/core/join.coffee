{getSender} = require '../../util'
Promise = require 'bluebird'

module.exports = ->
	return (client) ->
		client.join = (chan, cb) ->
			if chan instanceof Array
				if chan.length is 0
					return
				@raw "JOIN #{chan.join()}"
				joinPromises = for c in chan
					do (c) =>
						new Promise (resolve) =>
							@on ['join', c], ({chan, nick}) ->
								resolve chan
				return Promise.all(joinPromises).nodeify cb or @cbNoop

			else
				return new Promise (resolve) =>
					@raw "JOIN #{chan}"
					@once ['join', chan], ({chan, nick}) ->
						resolve chan
				.nodeify cb or @cbNoop

		client.on 'raw', (reply) ->
			if reply.command is 'JOIN'
				nick = getSender reply
				chan = reply.params[0]

				@emit 'join', {chan, nick}
				@emit ['join', chan], {chan, nick}
				# Because no one likes case sensitivity
				if chan.toLowerCase() isnt chan
					@emit ['join', chan.toLowerCase()], {chan, nick}