{getSender} = require '../../util'
Promise = require 'bluebird'

module.exports = ->
	return (client) ->

		###
		@overload #part(chan)
		  Parts a channel.

		  @param chan [String, Array] The channel or array of channels to part
		  @return [Promise<String>] A promise that resolves with the channel after successfully parting. If array of channels provided, it will resolve with them after they have all been parted.
		@overload #part(chan, reason)
		  Parts a channel with a reason message.

		  @param chan [String, Array] The channel or array of channels to part
		  @param reason [String] The reason message
		  @return [Promise<String>] A promise that resolves with the channel after successfully parting. If array of channels provided, it will resolve with them after they have all been parted.
		@overload #part(chan, cb)
		  Parts a channel.

		  @param chan [String, Array] The channel or array of channels to part
		  @param cb [Function] A callback that's called on successful part
		  @return [Promise<String>] A promise that resolves with the channel after successfully parting. If array of channels provided, it will resolve with them after they have all been parted.

		@overload #part(chan, reason, cb)
		  Parts a channel with a reason message.

		  @param chan [String, Array] The channel or array of channels to part
		  @param reason [String] The reason message
		  @param cb [Function] A callback that's called on successful part
		  @return [Promise<String>] A promise that resolves with the channel after successfully parting. If array of channels provided, it will resolve with them after they have all been parted.
		###
		client.part = (chan, reason, cb) ->
			if not reason?
				reason = ''
			else if reason instanceof Function
				cb = reason
				reason = ''
			else
				reason = ' :' + reason
			if chan instanceof Array and chan.length > 0
				@raw "PART #{chan.join()+reason}"
				partPromises = for c in chan
					do (c) =>
						new Promise (resolve) =>
							@once ['part', c], (channel, nick) ->
								resolve channel
				return Promise.all(partPromises).nodeify cb or @cbNoop

			else
				return new Promise (resolve) =>
					@raw "PART #{chan+reason}"
					@once ['part', chan], (channel, nick) ->
						resolve channel
				.nodeify cb or @cbNoop
		client.on 'raw', (reply) ->
			if reply.command is 'PART'
				nick = getSender reply
				chan = reply.params[0]
				reason = reply.params[1]
						
				@emit 'part', chan, nick, reason
				@emit ['part', chan], chan, nick, reason
				# Because no one likes case sensitivity
				if chan.toLowerCase() isnt chan
					@emit ['part', chan.toLowerCase()], chan, nick