chai = require 'chai'
{expect} = chai
should = chai.should()

Client = require '../src/client'

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
			true.should.be.false
		# TODO: write test to check loading config from file
		# TODO: write test to check user specified config is what the client uses
		
		# tests for actually connecting
		# TODO: check if verbose: false works