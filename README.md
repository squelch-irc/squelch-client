# node-irc-client


An IRC Client for Node.js written in CoffeeScript.

## Documentation
You can find the full documentation [here](http://rahatarmanahmed.github.io/node-irc-client/docs/index.html).

## Todo
 - SSL support
 - Reconnecting

## Installation
node-irc-client is not yet available from npm, but it will be once things are finished and cleaned up!

## Example usage
There will be more extensive examples soon. For now, here is a simple IRC echo bot in CoffeeScript.

	Client = require './src/client'

	client = new Client
		server: "irc.esper.net"
		nick: "TestBot"
		autoConnect: false
		channels: ["#kellyirc"]

	client.connect (nick) ->
		client.on 'msg', (from, to, msg) ->
			if to is "#kellyirc"
				client.msg to, "ECHO: #{msg}"

## Running tests
Grunt is used to run the tests. Clone the repo and run `npm install` and `npm install -g grunt-cli` for dependencies. Then to run the tests, run `grunt test`.

