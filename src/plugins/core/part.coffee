{getSender} = require '../../util'

module.exports = ->
	return (client) ->
		client.part = (channel, reason = '') ->
			if reason isnt ''
				reason = ' :' + reason
			channels = [].concat channel
			return if channels.length is 0
			@raw "PART #{channels.join()+reason}"

		client._.internalEmitter.on 'raw', (reply) ->
			if reply.command is 'PART'
				nick = getSender reply
				chan = reply.params[0]
				reason = reply.params[1]
				me = nick is client.nick()
				client.emit 'part', {chan, nick, reason, me}
