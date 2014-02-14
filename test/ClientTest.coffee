chai = require 'chai'
{expect} = chai
should = chai.should()

Client = require '../src/client'


class TestClient extends Client
	constructor: (opt) ->
		self = @
		opt.autoConnect = false
		super opt
		@rawLog = []
		@conn =
			write: (data) -> self.rawLog.push data
		@happened = (rawLine) ->
			rawLine += "\r\n"
			for line in @rawLog
				if line is rawLine
					return true
			return false


describe 'node-irc-client', ->

	describe 'constructor', ->
		it 'should throw an error with no arguments', ->
			expect ->
				client = new Client()
			.to.throw "No options argument given."
		it 'should throw an error with no server option', ->
			expect ->
				client = new Client
					port: 6697
					nick: "PakaluPapito"
					username: "PakaluPapito"
					realname: "PakaluPapito"
			.to.throw "No server specified."
		it 'should load the config from a file', ->
			client = new Client('./test/testConfig.json')
			client.opt.server.should.be.equal "irc.ircnetwork.net"
			client.opt.port.should.be.equal 6667
			client.opt.nick.should.be.equal "NodeIRCTestBot"
			client.opt.username.should.be.equal "NodeIRCTestBot"
			client.opt.realname.should.be.equal "I do the tests."
			client.opt.autoConnect.should.be.equal false

		# TODO: tests for actually connecting... how???

	describe 'handleReply simulations', ->
		client = null
		beforeEach ->
			client = new TestClient
				server: "irc.ircnet.net"
				nick: "PakaluPapito"
		it 'should respond to PINGs', ->
			client.handleReply "PING :FFFFFFFFBD03A0B0"
			client.happened("PONG :FFFFFFFFBD03A0B0").should.be.true
