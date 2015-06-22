chai = require 'chai'
{expect} = chai
should = chai.should()

net = require 'net'
tls = require 'tls'
fs = require 'fs'
path = require 'path'
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
		@isVerbose = false
		super()
		@expectQueue = []

		socketListener = (socket) =>
			if @socket?
				throw new Error 'This TestServer already has a client connected. Cannot connect more than one client to a test server.'
			@socket = socket
			@socket.on 'data', (data) =>
				for actual in data.toString('utf8').split('\r\n').filter((i) -> i)
					@log "Received #{actual}"
					expected = @expectQueue.shift()
					if not expected?
						throw new Error "Did not expect client to send: #{actual}"
					if expected.line is actual
						expected.deferred.resolve()
					else
						expected.deferred.reject {expected: expected.line, actual: actual}
			@socket.on 'error', (err) =>
				return if @clientQuitting && err.code is 'ECONNRESET'
				throw err

		if ssl
			opts =
				key: fs.readFileSync path.resolve __dirname, 'creds/key.pem'
				cert: fs.readFileSync path.resolve __dirname, 'creds/cert.pem'
			@server = tls.createServer opts, socketListener
				.listen(port)
		else
			@server = net.createServer socketListener
				.listen(port)

	log: (msg) -> console.log msg if @isVerbose
	expect: (lines) =>
		lines = [lines] if lines not instanceof Array
		promises = []
		for line in lines
			expected =
				line: line
				deferred: defer()
			@log "Expecting #{line}"
			@expectQueue.push expected
			promises.push expected.deferred.promise
		return Promise.all(promises).return().catch((e) -> e.actual.should.equal e.expected)

	reply: (rawLine) =>
		if rawLine instanceof Array
			@reply line for line in rawLine
		else
			@socket.write rawLine + '\r\n'

	close: =>
		return new Promise (resolve) =>
			@server.close()
			@socket.end() if @socket
			@server.once 'close', ->
				resolve()

	verbose: (enabled) =>
		@isVerbose = enabled

	clientQuitting: =>
		@clientQuitting = true

module.exports = TestServer
