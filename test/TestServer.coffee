chai = require 'chai'
{expect} = chai
should = chai.should()

net = require 'net'
tls = require 'tls'
Promise = require 'bluebird'
EventEmitter2 = require('eventemitter2').EventEmitter2

defer = ->
	resolve = reject = null
	promise = new Promise ->
		resolve = arguments[0]
		reject = arguments[1]
	return {resolve, reject, promise}


class TestServer extends EventEmitter2
	constructor: (port, ssl = false) ->
		super()
		@expectQueue = []

		socketListener = (socket) =>
			if @socket?
				throw new Error "This TestServer already has a client connected. Cannot connect more than one client to a test server."
			@socket = socket
			@socket.on 'data', (data) =>
				for actual in data.toString('utf8').split('\r\n').filter((i) -> i)
					expected = @expectQueue.shift()
					if not expected?
						throw new Error "Did not expect client to send: #{actual}"
					if expected.line is actual
						expected.deferred.resolve()
					else
						expected.deferred.reject {expected: expected.line, actual: actual}
		if ssl
			# TODO: do this with cert and key
			throw new Error "NOT YET IMPLEMENTED"
		else
			@server = net.createServer socketListener
				.listen(port)

	expect: (lines) =>
		lines = [lines] if lines not instanceof Array
		promises = []
		for line in lines
			expected =
				line: line
				deferred: defer()
			@expectQueue.push expected
			promises.push expected.deferred.promise
		return Promise.all(promises).return().catch((e) -> e.actual.should.equal e.expected)

	reply: (rawLine) =>
		if rawLine instanceof Array
			@reply line for line in rawLine
		else
			@socket.write rawLine + '\r\n'

	close: => @server.close()

module.exports = TestServer
