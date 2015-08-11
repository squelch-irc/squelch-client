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
						if @isConnected()
							reject msg

				removeListeners = =>
					@removeListener 'raw', errListener
					@removeListener 'nick', nickListener

				@on 'nick', nickListener
				@on 'raw', errListener

				@raw "NICK #{desiredNick}"
			.nodeify cb or @cbNoop

		client.on 'raw', (reply) ->
			if reply.command is 'NICK'
				oldNick = getSender reply
				newNick = reply.params[0]
				me = oldNick is @nick()
				if me
					@_.nick = newNick

				@emit 'nick', {oldNick, newNick, me}
			else if reply.command is getReplyCode 'ERR_NICKNAMEINUSE'
				if @opt.autoNickChange
					@_.numRetries++
					@nick @opt.nick + @_.numRetries
				else
					@disconnect()
