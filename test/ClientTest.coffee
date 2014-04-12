chai = require 'chai'
{expect} = chai
should = chai.should()

Client = require '../src/client'
TestClient = require './TestClient'

###
Thank you KR https://gist.github.com/raymond-h/709801d9f3816ff8f157#file-test-util-coffee
Allows mocha to catch assertions in async functions
usage (done being another callback to be called with thrown assert except.)
asyncFunc param, param, async(done) (err, data) ->
  hurr
###
async = (done) ->
	(callback) -> (args...) ->
			try callback args...
			catch e then done e

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

	it "should run the callback on successful disconnect", (done) ->
		client._.disconnecting.should.be.false
		client.disconnect async(done) () ->
			done()
		client._.disconnecting.should.be.true
		client.handleReply "ERROR :Closing Link: cpe-76-183-227-155.tx.res.rr.com (Client Quit)"
		client._.disconnecting.should.be.false

	it "should send a reason and run the callback on successful disconnect", (done) ->
		client._.disconnecting.should.be.false
		client.disconnect "Choke on it.", async(done) () ->
			done()
		client.happened("QUIT :Choke on it.").should.be.true
		client._.disconnecting.should.be.true
		client.handleReply "ERROR :Closing Link: cpe-76-183-227-155.tx.res.rr.com (Choke on it.)"
		client._.disconnecting.should.be.false

describe 'isConnected', ->
	client = null
	beforeEach ->
		client = new TestClient
			server: "irc.indiegames.net"
			nick: "PhilFish"
			verbose: false
	it "should only be true when connected to the server", ->
		client.isConnected().should.be.false
		client.handleReply ":irc.indiegames.net 001 PhilFish :Welcome to the IRCNet Internet Relay Chat Network PhilFish"
		client.isConnected().should.be.true
		client.disconnect("Choke on it.")
		client.handleReply "ERROR :Closing Link: cpe-76-183-227-155.tx.res.rr.com (Choke on it.)"
		# client.isConnected().should.be.false

describe 'verbose', ->
	client = null
	beforeEach ->
		client = new TestClient
			server: "irc.somewhere.net"
			nick: "Rando"
			verbose: false
	it 'should return the right value', ->
		client.verbose().should.be.false
		client.opt.verbose.should.be.false
	it 'should set the right value', ->
		client.verbose true
		client.verbose().should.be.true
		client.opt.verbose.should.be.true

describe 'kick', ->
	client = null
	beforeEach ->
		client = new TestClient
			server: "irc.somewhere.net"
			nick: "KingLeonidas"
			verbose: false
	it 'with single chan and nick', ->
		client.kick "#persia", "messenger"
		client.happened("KICK #persia messenger").should.be.true
	it 'with multiple chans and nicks', ->
		client.kick ["#persia", "#empire"], ["messenger1", "messenger2", "messenger3"]
		client.happened("KICK #persia,#empire messenger1,messenger2,messenger3").should.be.true
	it 'with a reason', ->
		client.kick "#persia", "messenger", "THIS IS SPARTA!"
		client.happened("KICK #persia messenger :THIS IS SPARTA!").should.be.true
		
describe 'nick', ->
	client = null
	beforeEach ->
		client = new TestClient
			server: "irc.ircnet.net"
			nick: "Cage"
			verbose: false
		client.handleReply ":irc.ircnet.net 001 Cage :Welcome to the IRCNet Internet Relay Chat Network Cage"

	it 'with no parameters should return the nick', ->
		client.nick().should.equal "Cage"

	it 'with one parameter should send a NICK command', ->
		client.nick "PricklyPear"
		client.happened("NICK PricklyPear").should.be.true

	it 'with two params should callback on success', (done) ->
		client.nick "PricklyPear", async(done) (err, oldNick, newNick) ->
			should.not.exist err
			oldNick.should.equal "Cage"
			newNick.should.equal "PricklyPear"
			client.listeners('nick').length.should.equal 0
			client.listeners('raw').length.should.equal 0
			done()
		client.happened("NICK PricklyPear").should.be.true
		client.handleReply ":Cage!~NodeIRCClient@cpe-76-183-227-155.tx.res.rr.com NICK :PricklyPear"

	it 'with two params should callback on error 432', (done) ->
		client.nick "!@#$%^&*()", async(done) (err, oldNick, newNick) ->
			err.command.should.equal "432"
			should.not.exist oldNick
			should.not.exist newNick
			client.listeners('nick').length.should.equal 0
			client.listeners('raw').length.should.equal 0
			done()
		client.happened("NICK !@#$%^&*()").should.be.true
		client.handleReply ":irc.ircnet.net 432 Cage !@#$%^&*() :Erroneous Nickname"


describe 'msg', ->
	client = null
	beforeEach ->
		client = new TestClient
			server: "irc.ircnet.net"
			nick: "PakaluPapito"
			verbose: false
		client.handleReply ":irc.ircnet.net 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito"

	it 'should send a PRIVMSG', ->
		client.msg "#girls", "u want to see gas station"
		client.msg "HotGurl22", "i show u gas station"
		client.happened([
			"PRIVMSG #girls :u want to see gas station"
			"PRIVMSG HotGurl22 :i show u gas station"
		]).should.be.true

describe 'action', ->
	client = null
	beforeEach ->
		client = new TestClient
			server: "irc.ircnet.net"
			nick: "PakaluPapito"
			verbose: false
		client.handleReply ":irc.ircnet.net 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito"

	it 'should send a PRIVMSG action', ->
		client.action "#girls", "shows u gas station"
		client.action "HotGurl22", "shows u camel"
		client.happened([
			"PRIVMSG #girls :\u0001ACTION shows u gas station\u0001"
			"PRIVMSG HotGurl22 :\u0001ACTION shows u camel\u0001"
		]).should.be.true

describe 'notice', ->
	client = null
	beforeEach ->
		client = new TestClient
			server: "irc.ircnet.net"
			nick: "PakaluPapito"
			verbose: false
		client.handleReply ":irc.ircnet.net 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito"

	it 'should send a NOTICE', ->
		client.notice "#girls", "u want to see gas station"
		client.notice "HotGurl22", "i show u gas station"
		client.happened([
			"NOTICE #girls :u want to see gas station"
			"NOTICE HotGurl22 :i show u gas station"
		]).should.be.true

describe 'join', ->
	client = null
	beforeEach ->
		client = new TestClient
			server: "irc.ircnet.net"
			nick: "Cage"
			verbose: false
		client.handleReply ":irc.ircnet.net 001 Cage :Welcome to the IRCNet Internet Relay Chat Network Cage"

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

describe 'invite', ->
	client = null
	beforeEach ->
		client = new TestClient
			server: "irc.ircnet.net"
			nick: "PakaluPapito"
			verbose: false
		client.handleReply ":irc.ircnet.net 001 PakaluPapito :Welcome to the IRCNet Internet Relay Chat Network PakaluPapito"
	it 'should send an INVITE', ->
		client.invite "HotBabe99", "#gasstation"
		client.happened("INVITE HotBabe99 #gasstation").should.be.true

describe 'part', ->
	client = null
	beforeEach ->
		client = new TestClient
			server: "irc.ircnet.net"
			nick: "Cage"
			verbose: false
		client.handleReply ":irc.ircnet.net 001 Cage :Welcome to the IRCNet Internet Relay Chat Network Cage"

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
