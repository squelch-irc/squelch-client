{getSender} = require '../../util'
{getReplyCode} = require '../../replies'

module.exports = ->
	return (client) ->
		client.nick = (desiredNick) ->
			return @_.nick if not desiredNick?
			@raw "NICK #{desiredNick}"

		client._.internalEmitter.on 'raw', (reply) ->
			if reply.command is 'NICK'
				oldNick = getSender reply
				newNick = reply.params[0]
				me = oldNick is client.nick()
				if me
					client._.nick = newNick

				client.emit 'nick', {oldNick, newNick, me}
			else if reply.command is getReplyCode 'ERR_NICKNAMEINUSE'
				return if client.isConnected()

				if client.opt.autoNickChange
					client._.numRetries++
					client.nick client.opt.nick + client._.numRetries
				else
					client.disconnect()
