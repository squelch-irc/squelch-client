{getSender} = require '../../util'
module.exports = ->
	return (client) ->

		###
		Invites a user to a channel.
		@param nick [String] The user to invite
		@param chan [String] The channel to invite the user to
		###
		client.invite = (nick, chan) ->
			@raw "INVITE #{nick} #{chan}"

		client.on 'raw', (reply) ->
			if reply.command is 'INVITE'
				from = getSender reply
				# don't need `to` because you don't get invites for other ppl
				chan = reply.params[1]
				@emit 'invite', from, chan