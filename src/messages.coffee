# messages.coffee
#
# Use jQuery.blockUI to notify the user of messages.

module 'messages', imports('plugin'), ->

	# Handle the various types of messages:
	# undefined, a text string, a text string contained in a 'desc' property,
	# or an object that needs to be converted to JSON format.
	the_message = (msg) ->
		switch
			when not msg? then ''
			when typeof msg is 'string' then msg
			when msg.desc? then msg.desc
			else JSON.stringify msg

	promptUI = (title, message, timeout, cb) ->
		$m = $('<div class="promptUI"></div>')
		$m.append("<h1>#{title}</h1>") if title
		$m.append("<h2>#{message}</h2>") if message
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

	$.fn.messages = ->
		@plugin('messages')

		# A notice shows up on the screen and then times out automatically.
		.subscribe 'notice', (type, xs) ->
			(xs = [xs]) unless $.isArray xs
			$.growlUI(type, the_message(x), 1000) for x in xs
			return false

		# A prompt normally stays on the screen prompting for user feedback.
		# It can be instrumented perform an action if the user clicks ok button before a timeout.
		.subscribe 'prompt', (type, xs, timeout, cb) ->
			(xs = [xs]) unless $.isArray xs
			promptUI(type, the_message(x), timeout, cb) for x in xs
			return false
