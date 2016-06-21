{getSender} = require '../../util'
Promise = require 'bluebird'

module.exports = ->
	return (client) ->
		client.join = (channel, key = '') ->
			channels = [].concat channel
			return if channels.length is 0
			@raw "JOIN #{channels.join()} #{key}".trim()

		client._.internalEmitter.on 'raw', (reply) ->
			if reply.command is 'JOIN'
				nick = getSender reply
				chan = reply.params[0]
				me = nick is client.nick()
				client.emit 'join', {chan, nick, me}
