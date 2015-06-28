{getSender} = require '../../util'
module.exports = ->
	return (client) ->
		client.invite = (nick, chan) ->
			@raw "INVITE #{nick} #{chan}"

		client.on 'raw', (reply) ->
			if reply.command is 'INVITE'
				from = getSender reply
				chan = reply.params[1]
				@emit 'invite', {from, chan}