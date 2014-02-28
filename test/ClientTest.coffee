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
		# Checks output log to see if the client ever sent the given line
		# If param is array, returns true if all lines are in the log
		@happened = (rawLine) ->
			if rawLine instanceof Array
				return false if not @happened line for line in rawLine
				return true
			rawLine += "\r\n"
			return true if line is rawLine for line in @rawLog
			return false
		@handleReplies = (replies) ->
			for reply in replies
				@handleReply reply

# Thank you KR https://gist.github.com/raymond-h/709801d9f3816ff8f157#file-test-util-coffee
# Allows mocha to catch assertions in async functions
# usage (done being another callback to be called with thrown assert except.)
# asyncFunc param, param, async(done) (err, data) ->
#   hurr
async = (done) ->
	(callback) -> (args...) ->
			try callback args...
			catch e then done e



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
			client.opt.server.should.equal "irc.ircnetwork.net"
			client.opt.port.should.equal 6667
			client.opt.nick.should.equal "NodeIRCTestBot"
			client.opt.username.should.equal "NodeIRCTestBot"
			client.opt.realname.should.equal "I do the tests."
			client.opt.autoConnect.should.equal false

	describe 'disconnect', ->
		client = null
		beforeEach ->
			client = new TestClient
				server: "irc.indiegames.net"
				nick: "PhilFish"
				verbose: false

		it "should send QUIT to the server and null the connection", ->
			client.disconnect()
			client.happened("QUIT").should.be.true

		it "should send a reason with the QUIT", ->
			client.disconnect "Choke on it."
			client.happened("QUIT :Choke on it.").should.be.true

	describe 'nick', ->
		client = null
		beforeEach ->
			client = new TestClient
				server: "irc.ircnet.net"
				nick: "Cage"
				verbose: false
			client.handleReply ":irc.ircnet.net 001 Cage :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito"

		it 'with no parameters should return the nick', ->
			client.nick().should.equal "Cage"

		it 'with one parameter should send a NICK command', ->
			client.nick "PricklyPear"
			client.happened("NICK PricklyPear").should.be.true

	describe 'join', ->
		client = null
		beforeEach ->
			client = new TestClient
				server: "irc.ircnet.net"
				nick: "Cage"
				verbose: false
			client.handleReply ":irc.ircnet.net 001 Cage :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito"

		it 'a single channel', ->
			client.join "#furry"
			client.happened("JOIN #furry").should.be.true


		it 'a single channel with a callback', (done) ->
			client.join "#furry", async(done) (chan, nick) ->
				chan.should.be.equal "#furry"
				nick.should.be.equal "Cage"
				done()
			client.handleReply ":Cage!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #furry"

		it 'an array of channels', ->
			client.join ["#furry", "#wizard", "#jayleno"]
			client.happened("JOIN #furry,#wizard,#jayleno").should.be.true

		it 'an array of channels with a callback', ->
			it 'should work for one channel in the array', ->
				client.join ["#furry", "#wizard"], async(done) (chan, nick) ->
					chan.should.be.equal "#furry"
					nick.should.be.equal "Cage"
					done()
				client.handleReply ":Cage!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #furry"
			it 'should work for another channel in the array', ->
				client.join ["#furry", "#wizard"], async(done) (chan, nick) ->
					chan.should.be.equal "#wizard"
					nick.should.be.equal "Cage"
					done()
				client.handleReply ":Cage!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com JOIN #wizard"

	describe 'part', ->
		client = null
		beforeEach ->
			client = new TestClient
				server: "irc.ircnet.net"
				nick: "Cage"
				verbose: false
			client.handleReply ":irc.ircnet.net 001 Cage :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito"

		it 'a single channel', ->
			client.part "#furry"
			client.happened("PART #furry").should.be.true

		it 'a single channel with a reason', ->
			client.part "#furry", "I'm leaving."
			client.happened("PART #furry :I'm leaving.").should.be.true

		it 'a single channel with a callback', (done) ->
			client.part "#furry", async(done) (chan, nick) ->
				chan.should.be.equal "#furry"
				nick.should.be.equal "Cage"
				done()
			client.handleReply ":Cage!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #furry"

		it 'a single channel with a reason and callback', (done) ->
			client.part "#furry", "I'm leaving.", async(done) (chan, nick) ->
				chan.should.be.equal "#furry"
				nick.should.be.equal "Cage"
				done()
			client.happened("PART #furry :I'm leaving.").should.be.true
			client.handleReply ":Cage!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #furry"

		it 'an array of channels', ->
			client.part ["#furry", "#wizard", "#jayleno"]
			client.happened("PART #furry,#wizard,#jayleno").should.be.true

		it 'an array of channels with a reason', ->
			client.part ["#furry", "#wizard", "#jayleno"], "I'm leaving."
			client.happened("PART #furry,#wizard,#jayleno :I'm leaving.").should.be.true

		it 'an array of channels with a callback', ->
			it 'should work for one channel in the array', ->
				client.part ["#furry", "#wizard"], async(done) (chan, nick) ->
					chan.should.be.equal "#furry"
					nick.should.be.equal "Cage"
					done()
				client.handleReply ":Cage!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #furry"
			it 'should work for another channel in the array', ->
				client.part ["#furry", "#wizard"], async(done) (chan, nick) ->
					chan.should.be.equal "#wizard"
					nick.should.be.equal "Cage"
					done()
				client.handleReply ":Cage!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #wizard"

		it 'an array of channels with a reason and callback', ->
			it 'should work for one channel in the array', ->
				client.part ["#furry", "#wizard"], "I'm leaving", async(done) (chan, nick) ->
					chan.should.be.equal "#furry"
					nick.should.be.equal "Cage"
					done()
				client.happened("PART #furry,#wizard,#jayleno :I'm leaving.").should.be.true
				client.handleReply ":Cage!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #furry"
			it 'should work for another channel in the array', ->
				client.part ["#furry", "#wizard"], "I'm leaving", async(done) (chan, nick) ->
					chan.should.be.equal "#wizard"
					nick.should.be.equal "Cage"
					done()
				client.happened("PART #furry,#wizard,#jayleno :I'm leaving.").should.be.true
				client.handleReply ":Cage!~NodeIRCCl@cpe-76-183-227-155.tx.res.rr.com PART #wizard"

	describe 'handleReply simulations', ->
		client = null

		beforeEach ->
			client = new TestClient
				server: "irc.ircnet.net"
				nick: "PakaluPapito"
				channels: ["#sexy", "#furry"]
				verbose: false
			client.handleReply ":irc.ircnet.net 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito"

		describe 'raw', ->
			it 'should emit raw event for a reply', (done) ->
				client.once 'raw', async(done) (msg) ->
					msg.command.should.equal "PING"
					msg.params[0].should.equal "FFFFFFFFBD03A0B0"
					done()
				client.handleReply "PING :FFFFFFFFBD03A0B0"

			it 'should emit raw event for some other reply', (done) ->
				client.once 'raw', async(done) (msg) ->
					msg.command.should.equal "PRIVMSG"
					msg.params[0].should.equal "#kellyirc"
					msg.params[1].should.equal "Current modules are..."
					done()
				client.handleReply ":Kurea!~Kurea@162.243.123.251 PRIVMSG #kellyirc :Current modules are..."

		describe '001', ->
			it 'should save its given nick', ->
				client._.nick.should.equal "PakaluPapito"

			it 'should emit a connect event with the right nick', (done) ->
				# Need to attach the listener before it handles the reply
				client = new TestClient
					server: "irc.ircnet.net"
					nick: "PakaluPapito"
					verbose: false
				client.once 'connect', async(done) (nick) ->
					nick.should.equal "PakaluPapito"
					done()
				client.handleReply ":irc.ircnet.net 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito"

			it 'should auto join the channels in opt.channels', ->
				client.happened("JOIN #sexy,#furry").should.be.true

		describe '372,375,376 (motd)', ->
			it 'should save the motd properly and emit a motd event', (done) ->
				# Thank you Brian Lee https://twitter.com/LRcomic/status/434440616051634176
				client.once 'motd', async(done) (motd) ->
					motd.should.equal "irc.ircnet.net Message of the Day\r\n\
						THE ROSES ARE RED\r\n\
						THE VIOLETS ARE BLUE\r\n\
						IGNORE THIS LINE\r\n\
						THIS IS A HAIKU\r\n"
					done()

				client.handleReplies [
					":irc.ircnet.net 375 PakaluPapito :irc.ircnet.net Message of the Day"
					":irc.ircnet.net 372 PakaluPapito :THE ROSES ARE RED"
					":irc.ircnet.net 372 PakaluPapito :THE VIOLETS ARE BLUE"
					":irc.ircnet.net 372 PakaluPapito :IGNORE THIS LINE"
					":irc.ircnet.net 372 PakaluPapito :THIS IS A HAIKU"
					":irc.ircnet.net 376 PakaluPapito :End of /MOTD command."
				]

		describe '433', ->
			it 'should automatically try a new nick', ->
				# This happens before the 001 event so need to make a new client
				client = new TestClient
					server: "irc.ircnet.net"
					nick: "PakaluPapito"
					verbose: false
				client.handleReply ":irc.ircnet.net 433 * PakaluPapito :Nickname is already in use."
				client.happened "NICK PakaluPapito1"
				client.handleReply ":irc.ircnet.net 433 * PakaluPapito1 :Nickname is already in use."
				client.happened "NICK PakaluPapito2"
				client.handleReply ":irc.ircnet.net 433 * PakaluPapito2 :Nickname is already in use."
				client.happened "NICK PakaluPapito3"

		describe 'ping', ->
			it 'should respond to PINGs', ->
				client.handleReply "PING :FFFFFFFFBD03A0B0"
				client.happened("PONG :FFFFFFFFBD03A0B0").should.be.true

		describe 'join', ->
			it 'should emit a join event', (done) ->
				client.once 'join', async(done) (chan, nick) ->
					chan.should.equal "#testChan"
					nick.should.equal "lawblob"
					done()
				client.handleReply ":lawblob!~lawblobuser@cpe-76-183-227-155.tx.res.rr.com JOIN #testChan"

			it 'should emit a join#chan event', (done) ->
				client.once 'join#testChan', async(done) (chan, nick) ->
					chan.should.equal "#testChan"
					nick.should.equal "lawblob"
					done()
				client.handleReply ":lawblob!~lawblobuser@cpe-76-183-227-155.tx.res.rr.com JOIN #testChan"

			it 'should emit a join#chan event in lowercase', (done) ->
				client.once 'join#testchan', async(done) (chan, nick) ->
					chan.should.equal "#testChan"
					nick.should.equal "lawblob"
					done()
				client.handleReply ":lawblob!~lawblobuser@cpe-76-183-227-155.tx.res.rr.com JOIN #testChan"

		describe 'part', ->
			it 'should emit a part event', (done) ->
				client.once 'part', async(done) (chan, nick) ->
					chan.should.equal "#testChan"
					nick.should.equal "lawblob"
					done()
				client.handleReply ":lawblob!~lawblobuser@cpe-76-183-227-155.tx.res.rr.com PART #testChan"

			it 'should emit a part#chan event', (done) ->
				client.once 'part#testChan', async(done) (chan, nick) ->
					chan.should.equal "#testChan"
					nick.should.equal "lawblob"
					done()
				client.handleReply ":lawblob!~lawblobuser@cpe-76-183-227-155.tx.res.rr.com PART #testChan"

			it 'should emit a part#chan event in lowercase', (done) ->
				client.once 'part#testchan', async(done) (chan, nick) ->
					chan.should.equal "#testChan"
					nick.should.equal "lawblob"
					done()
				client.handleReply ":lawblob!~lawblobuser@cpe-76-183-227-155.tx.res.rr.com PART #testChan"

		describe 'nick', ->
			it 'should emit a nick event', (done) ->
				client.once 'nick', async(done) (oldnick, newnick) ->
					oldnick.should.equal "SnoopDogg"
					newnick.should.equal "SnoopLion"
					done()
				client.handleReply ":SnoopDogg!~SnoopUser@cpe-76-183-227-155.tx.res.rr.com NICK :SnoopLion"

			it 'should update its own nick', ->
				client._.nick.should.equal "PakaluPapito"
				client.handleReply ":PakaluPapito!~NodeIRCClient@cpe-76-183-227-155.tx.res.rr.com NICK :SteelUrGirl"
				client._.nick.should.equal "SteelUrGirl"

