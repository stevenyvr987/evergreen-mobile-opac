# We defne a module to define a jQuery plugin to show messages to the user in a
# dialog box.  The plugin will subscribe to two data channels for message
# content.
#
# 1. On the 'notice' channel, the plugin will show messages
# that times out automatically.
# Notices are primarily used for showing progress messages.
#
# 2. On the 'prompt' channel, the plugin will show messages
# that will stay until the user confirms the message.
# Prompts are primarily used for showing error messages.
define [
	'jquery'
	'jqm_sd'
	'plugin'
], ($) ->

	# Define a helper function to convert the type of message to be displayed into a text string.
	the_message = (msg) ->
		switch
			when not msg? then '' # undefined,
			when typeof msg is 'string' then msg # a text string,
			when msg.desc? then msg.desc # a text string contained in a 'desc' property,
			else JSON.stringify msg # or an object that needs to be converted to JSON format.

	# Define the behaviour of the prompt box. Content panel is blank until
	# filled in by message text. Message box will be positioned at the top of
	# current page and will take 80% of the available width.
	promptly =
		mode: 'blank'
		top: true
		width: '80%'

	# Define the additional behaviour of the notice box.  There is a close
	# button in the header, and the box does not animate.
	notably =
		headerClose: true
		animate: false

	$.fn.messages = ->
		@plugin('messages')

		# Upon receving a notice, show any messages for a brief time.
		.subscribe 'notice', (xs) ->
			setTimeout((-> $.mobile.sdCurrentDialog.close()), 2000)
			(xs = [xs]) unless $.isArray xs
			for x in xs
				$('<div>').simpledialog2 $.extend {}, promptly,
					blankContent: "<h3 class='message'>#{the_message x}</h3>"
			return false

		# Upon receiving a prompt, show any messages until the user clicks the close button.
		.subscribe 'prompt', (type, xs) ->
			(xs = [xs]) unless $.isArray xs
			for x in xs
				$('<div>').simpledialog2 $.extend {}, promptly, notably,
					headerText: type
					blankContent: "<h3 class='message'>#{the_message x}</h3>"
			return false
