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

	# Define the basic behaviour of the message box. Content panel is blank
	# until filled in by message text. Message box will be positioned at the
	# top of current page and will take 80% of the available width.
	sd_behaviour =
		mode: 'blank'
		top: true
		width: '80%'

	$.fn.messages = ->
		@plugin('messages')

		# Upon receving a notice, show any messages for a brief time.
		.subscribe 'notice', (xs) =>
			setTimeout((-> $.mobile.sdCurrentDialog.close()), 2000)
			$.mobile.changePage @
			(xs = [xs]) unless $.isArray xs
			for x in xs
				@simpledialog2 $.extend {}, sd_behaviour,
					blankContent: "<h3 class='message'>#{the_message x}</h3>"
			return false

		# Upon receiving a prompt, show any messages until the user clicks the button.
		.subscribe 'prompt', (type, xs) =>
			$.mobile.changePage @
			(xs = [xs]) unless $.isArray xs
			for x in xs
				@simpledialog2 $.extend {}, sd_behaviour,
					headerText: type
					headerClose: true
					blankContent: "<h3 class='message'>#{the_message x}</h3>"
					animate: false
			return false
