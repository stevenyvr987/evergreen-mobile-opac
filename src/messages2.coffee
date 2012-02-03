jMod.include 'lib.jquery_mobile_simpledialog_min'

module 'messages2', imports('plugin'), ->

	# Define a helper function to convert the type of message to be displayed into a text string.
	the_message = (msg) ->
		switch
			when not msg? then '' # undefined,
			when typeof msg is 'string' then msg # a text string,
			when msg.desc? then msg.desc # a text string contained in a 'desc' property,
			else JSON.stringify msg # or an object that needs to be converted to JSON format.

	$.fn.messages = ->
		@plugin('messages')

		# Upon receving a notice, show any messages for a brief time.
		.subscribe 'notice', (type, xs) =>
			tOut = setTimeout(
				-> history.back()
				2000
			)
			$.mobile.changePage @
			(xs = [xs]) unless $.isArray xs
			for x in xs
				@simpledialog
					prompt: type
					subTitle: the_message x
					mode: 'bool'
					cleanOnClose: true
					buttons: OK: hidden: true
			return false

		# Upon receiving a prompt, show any messages until the user clicks the button.
		.subscribe 'prompt', (type, xs) =>
			$.mobile.changePage @
			(xs = [xs]) unless $.isArray xs
			for x in xs
				@simpledialog
					prompt: type
					subTitle: the_message x
					mode: 'bool'
					cleanOnClose: true
					buttons: OK: click: ->
						history.back()
						return true
			return false
