codeToName = require 'irc-replies'
nameToCode = {}
Object.keys(codeToName).forEach (code) ->
	nameToCode[codeToName[code]] = code

module.exports =
	getReplyName: (code) -> codeToName[code.toString()]
	getReplyCode: (name) -> nameToCode[name.toUpperCase()]