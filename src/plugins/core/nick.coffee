{getSender} = require '../../util'
{getReplyCode} = require '../../replies'
Promise = require 'bluebird'

module.exports = ->
	return (client) ->

		###
		@overload #nick()
		  Gets the client's current nickname.
		  @return [String] The bot's current nickname.
		
		@overload #nick(desiredNick)
		  Changes the client's nickname.
		  @param desiredNick [String] The new nickname to change to.
		  @return [Promise<Object,Object>] A promise that resolves with an object containing oldNick and newNick on successful nick change, and rejects with the parsed reply of the nick change error when the server rejects a nick change

		@overload #nick(desiredNick, cb)
		  Changes the client's nickname, with a callback for success or failure.
		  @param desiredNick [String] The new nickname to change to.
		  @param cb [function] (err, old, new) If successful, err will be undefined, otherwise err will be the parsed message object of the error
		  @return [Promise<Object,Object>] A promise that resolves with an object containing oldNick and newNick on successful nick change, and rejects with the parsed reply of the nick change error when the server rejects a nick change
		###
		client.nick = (desiredNick, cb) ->
			return @_.nick if not desiredNick?
			return new Promise (resolve, reject) =>
				nickListener = (oldNick, newNick) ->
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
				oldnick = getSender reply
				newnick = reply.params[0]
				if oldnick is @nick()
					@_.nick = newnick

				@emit 'nick', oldnick, newnick
			else if reply.command is getReplyCode 'ERR_NICKNAMEINUSE'
				if @opt.autoNickChange
					@_.numRetries++
					@nick @opt.nick + @_.numRetries
				else
					@disconnect()