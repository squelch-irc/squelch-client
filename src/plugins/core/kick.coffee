{getSender} = require '../../util'
module.exports = ->
	return (client) ->

		###
		@overload #kick(chan, nick)
		  Kicks a user from a channel.

		  @param chan [String, Array] The channel or array of channels to kick in
		  @param nick [String, Array] The channel or array of nicks to kick

		@overload #kick(chan, nick, reason)
		  Kicks a user from a channel with a reason.

		  @param chan [String, Array] The channel or array of channels to kick in
		  @param nick [String, Array] The channel or array of nicks to kick
		  @param reason [String] The reason to give when kicking
		###
		client.kick = (chan, user, reason) ->
			chans = [].concat chan
			users = [].concat user
			if reason?
				reason = ' :' + reason
			else
				reason = ''
			for c in chans
				for u in users
					@raw "KICK #{c} #{u}#{reason}"

		client.on 'raw', (reply) ->
			if reply.command is 'KICK'
				kicker = getSender reply
				chan = reply.params[0]
				nick = reply.params[1]
				reason = reply.params[2]
						
				@emit 'kick', chan, nick, kicker, reason