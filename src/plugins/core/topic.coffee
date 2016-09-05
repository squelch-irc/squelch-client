{getReplyCode} = require '../../replies'

module.exports = ->
	return (client) ->
		client.topic = (channel, topic) ->
			return client.raw "TOPIC #{channel} :#{topic}" if topic?
			client.raw "TOPIC #{channel}"

		client._.internalEmitter.on 'raw', (reply) ->
			if reply.command is getReplyCode 'RPL_NOTOPIC'
				client.emit 'topic', {chan: reply.params[1], topic: ''}
			if reply.command is getReplyCode 'RPL_TOPIC'
				client.emit 'topic', {chan: reply.params[1], topic: reply.params[2]}
			if reply.command is getReplyCode 'RPL_TOPIC_WHO_TIME'
				client.emit 'topicwho',
					chan: reply.params[1]
					hostmask: reply.params[2]
					time: new Date parseInt(reply.params[3])
