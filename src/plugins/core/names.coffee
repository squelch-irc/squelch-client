{getReplyCode} = require '../../replies'

module.exports = ->
	return (client) ->

		client._.internalEmitter.on 'raw', (reply) ->
			if reply.command is getReplyCode 'RPL_NAMREPLY'
				# TODO: trigger event on name update
				chan = reply.params[2]
				client._.namesBuffer[chan] ?= {}
				buffer = client._.namesBuffer[chan]

				return if not chan?
				for name in reply.params[3].split ' '
					if client._.reversePrefix[name[0]]?
						buffer[name[1..]] = name[0]
					else
						buffer[name] = ''
			if reply.command is getReplyCode 'RPL_ENDOFNAMES'
				chan = reply.params[1]
				client.emit 'names', {chan, names: client._.namesBuffer[chan]}
				# Clear buffer
				delete client._.namesBuffer[chan]
