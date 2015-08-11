{getSender} = require '../../util'
module.exports = ->
	return (client) ->
		client.invite = (nick, chan) ->
			@raw "INVITE #{nick} #{chan}"

		client._.internalEmitter.on 'raw', (reply) ->
			if reply.command is 'INVITE'
				from = getSender reply
				chan = reply.params[1]
				client.emit 'invite', {from, chan}
