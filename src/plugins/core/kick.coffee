{getSender} = require '../../util'
module.exports = ->
	return (client) ->
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

		client._.internalEmitter.on 'raw', (reply) ->
			if reply.command is 'KICK'
				kicker = getSender reply
				chan = reply.params[0]
				nick = reply.params[1]
				reason = reply.params[2]
				me = nick is client.nick()

				client.emit 'kick', {chan, nick, kicker, reason, me}
