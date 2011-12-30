# We defne a module called 'messages'.
# The module is a jQuery plugin to show messages to the user in a dialog box.
# The plugin will subscribe to two data channels for message content.
#
# 1. On the 'notice' channel, the plugin will show messages
# that times out automatically.
# Notices are primarily used for showing progress messages.
#
# 2. On the 'prompt' channel, the plugin will show messages
# that will stay until the user confirms the message.
# Prompts are primarily used for showing error messages.

# The plugin is actually a wrapper around the jQuery.blockUI plugin.
# Here, we synchronously load the base plugin because it is not a jMod module.
jMod.include 'lib.jquery_blockUI'

module 'messages', imports('plugin'), ->

	# Customize the layout and behaviour of jQuery.blockUI for our purposes.
	$.extend $.blockUI.defaults,
		message: "Error. Reload the page."
		applyPlatformOpacityRules: false
	$.blockUI.defaults.css = {} # Styles for jQuery.blockUI are defined in CSS files.
	$.blockUI.defaults.overlayCSS = {}
	$.blockUI.defaults.overlayCSS.opacity = 0.6
	$.blockUI.defaults.overlayCSS['-ms-filter'] = 'progid:DXImageTransform.Microsoft.Alpha(Opacity=60)'
	$.blockUI.defaults.overlayCSS.filter = 'alpha(opacity=60)'
	$.blockUI.defaults.growlCSS.opacity = 0.9
	$.blockUI.defaults.growlCSS['-ms-filter'] = 'progid:DXImageTransform.Microsoft.Alpha(Opacity=90)'
	$.blockUI.defaults.growlCSS.filter = 'alpha(opacity=90)'

	# > FIXME: if external growlCSS is used, we get layout problem.
	#$.blockUI.defaults.growlCSS = {}


	# Define a helper function to convert the type of message to be displayed into a text string.
	the_message = (msg) ->
		switch
			when not msg? then '' # undefined,
			when typeof msg is 'string' then msg # a text string,
			when msg.desc? then msg.desc # a text string contained in a 'desc' property,
			else JSON.stringify msg # or an object that needs to be converted to JSON format.


	# Define the prompt dialog.
	# The message will be structured as a title followed by a body followed by a continue button.
	# It can be instrumented to perform an action if the user clicks the button before a timeout.
	promptUI = (title, body, timeout, cb) ->
		$m = $('<div class="promptUI"></div>')
		$m.append("<h1>#{title}</h1>") if title
		$m.append("<h2>#{body}</h2>") if body
		$m.append('<button>Continue</button>').click -> $.unblockUI()
		$.blockUI {
			message: $m
			fadeIn: 700
			fadeOut: 1000
			centerY: false
			timeout: timeout or 0
			onBlock: if cb then (-> $m.delegate 'button', 'click', cb) else null
			css: $.blockUI.defaults.growlCSS
		}


	# Define the jQuery plugin called 'messages'.
	$.fn.messages = ->
		@plugin('messages')

		# Upon receving a notice, show any messages for a brief time.
		.subscribe 'notice', (type, xs) ->
			(xs = [xs]) unless $.isArray xs
			$.growlUI(type, the_message(x), 1000) for x in xs
			return false

		# Upon receiving a prompt, show any messages until the user clicks the button.
		.subscribe 'prompt', (type, xs, timeout, cb) ->
			(xs = [xs]) unless $.isArray xs
			promptUI(type, the_message(x), timeout, cb) for x in xs
			return false
