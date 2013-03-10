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
	'jqm_sd'
	'plugin'
], -> (($) ->

	# Define a helper function to convert the type of message to be displayed into a text string.
	the_message = (msg) ->
		switch
			when not msg? then '' # undefined,
			when typeof msg is 'string' then msg # a text string,
			when msg.desc? then msg.desc # a text string contained in a 'desc' property,
			else JSON.stringify msg # or an object that needs to be converted to JSON format.

	# Define the behaviour of the notice box. Content panel is blank until
	# filled in by message text. Message box will be positioned at the top of
	# current page and will take 80% of the available width.
	notably =
		mode: 'blank'
		top: true
		width: '80%'

	open_notice = (text) ->
		$('<div>').simpledialog2 $.extend {}, notably,
			blankContent: "<h3 class='message'>#{text}</h3>"

	close_notice = -> $.mobile.sdCurrentDialog.close()

	# Define the additional behaviour of the prompt box.  There is a close
	# button in the header, and the box does not animate.
	promptly =
		headerClose: true
		animate: false

	open_prompt = (type, text) ->
		$('<div>').simpledialog2 $.extend {}, notably, promptly,
			headerText: type
			blankContent: "<h3 class='message'>#{text}</h3>"
		return

	###
	open_notice = (text) ->
		$('#messages').html("<h3 class='message'>#{text}</h3>").trigger 'create'
		$.mobile.changePage '#messages', transition: 'pop', role: 'dialog'
	open_prompt = (type, text) ->
		$('#messages').html("<h3 class='message'>#{type}</h3>").trigger 'create'
		$.mobile.changePage '#messages', transition: 'pop', role: 'dialog'
	close_notice = -> $('#messages').dialog 'close'
	###

	$.fn.messages = ->
		@plugin('messages')

		# Upon receving a notice, show any messages and hide them after a brief time.
		.subscribe 'notice', (xs) ->
			(xs = [xs]) unless $.isArray xs
			(open_notice the_message x) for x in xs
			setTimeout close_notice, 2000
			return false

		# Upon receiving a prompt, show any messages until the user hides them.
		.subscribe 'prompt', (type, xs) ->
			(xs = [xs]) unless $.isArray xs
			(open_prompt type, the_message x) for x in xs
			return false
)(jQuery)
