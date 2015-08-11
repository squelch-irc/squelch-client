{getSender} = require '../../util'
{getReplyCode} = require '../../replies'
Promise = require 'bluebird'

module.exports = ->
	return (client) ->
		client.nick = (desiredNick, cb) ->
			return @_.nick if not desiredNick?
			return new Promise (resolve, reject) =>
				nickListener = ({oldNick, newNick}) ->
					if newNick is desiredNick
						removeListeners()
						resolve {oldNick, newNick}
				errListener = (msg) ->
					if 431 <= parseInt(msg.command) <= 436 # irc errors for nicks
						removeListeners()
						# Don't error while we're still trying to connect
						if client.isConnected()
							reject msg

				removeListeners = =>
					client._.internalEmitter.off 'raw', errListener
					client._.internalEmitter.off 'nick', nickListener

				@_.internalEmitter.on 'nick', nickListener
				@_.internalEmitter.on 'raw', errListener

				@raw "NICK #{desiredNick}"
			.nodeify cb or @cbNoop

		client._.internalEmitter.on 'raw', (reply) ->
			if reply.command is 'NICK'
				oldNick = getSender reply
				newNick = reply.params[0]
				me = oldNick is client.nick()
				if me
					client._.nick = newNick

				client.emit 'nick', {oldNick, newNick, me}
			else if reply.command is getReplyCode 'ERR_NICKNAMEINUSE'
				if client.opt.autoNickChange
					client._.numRetries++
					client.nick client.opt.nick + client._.numRetries
				else
					client.disconnect()
