{getSender} = require '../../util'
Promise = require 'bluebird'

module.exports = ->
	return (client) ->

		###
		@overload #join(chan)
		  Joins a channel.

		  @param chan [String, Array] The channel or array of channels to join
		  @return [Promise<String>] A promise that resolves with the channel after successfully joining. If array of channels provided, it will resolve with them after they have all been joined.
		@overload #join(chan, cb)
		  Joins a channel.

		  @param chan [String, Array] The channel or array of channels to join
		  @param cb [Function] A callback that's called on successful join
		  @return [Promise<String>] A promise that resolves with the channel after successfully joining. If array of channels provided, it will resolve with them after they have all been joined.
		###
		client.join = (chan, cb) ->
			if chan instanceof Array
				if chan.length is 0
					return
				@raw "JOIN #{chan.join()}"
				joinPromises = for c in chan
					do (c) =>
						new Promise (resolve) =>
							@on ['join', c], (channel, nick) ->
								resolve channel
				return Promise.all(joinPromises).nodeify cb or @cbNoop

			else
				return new Promise (resolve) =>
					@raw "JOIN #{chan}"
					@once ['join', chan], (channel, nick) ->
						resolve channel
				.nodeify cb or @cbNoop

		client.on 'raw', (reply) ->
			if reply.command is 'JOIN'
				nick = getSender reply
				chan = reply.params[0]

				@emit 'join', chan, nick
				@emit ['join', chan], chan, nick
				# Because no one likes case sensitivity
				if chan.toLowerCase() isnt chan
					@emit ['join', chan.toLowerCase()], chan, nick