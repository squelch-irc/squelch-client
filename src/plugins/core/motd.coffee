{getReplyCode} = require '../../replies'
module.exports = ->
	return (client) ->
		client._.internalEmitter.on 'raw', (reply) ->
			if reply.command is getReplyCode 'RPL_MOTD'
				client._.MOTD += reply.params[1] + '\r\n'
			if reply.command is getReplyCode 'RPL_MOTDSTART'
				client._.MOTD = reply.params[1] + '\r\n'
			if reply.command is getReplyCode 'RPL_ENDOFMOTD'
				client.emit 'motd', {motd: client._.MOTD}
