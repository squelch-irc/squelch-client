{getSender} = require '../../util'
Promise = require 'bluebird'

module.exports = ->
	return (client) ->
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