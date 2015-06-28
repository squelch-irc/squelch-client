{getReplyCode} = require '../../replies'
module.exports = ->
	return (client) ->
		client.on 'raw', (reply) ->
			if reply.command is getReplyCode 'RPL_MOTD'
				@_.MOTD += reply.params[1] + '\r\n'
			if reply.command is getReplyCode 'RPL_MOTDSTART'
				@_.MOTD = reply.params[1] + '\r\n'
			if reply.command is getReplyCode 'RPL_ENDOFMOTD'
				@emit 'motd', {motd: @_.MOTD}