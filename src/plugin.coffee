# plugin.coffee
#
# A jMod module defining jQuery methods
# for defining app-level plugins,
# and publishing and subscribing to data channels.

module 'plugin', imports('eg.eg_api'), (eg) ->

	# Common actions that are applied to all plugins.
	$.fn.plugin = (x) ->
		if x then @addClass "plugin #{x}" else @hasClass "plugin"

	# Subscribe to a data channel. Stores a reference to the plugin and callback
	# function in the subscriptions object, under the channel name.
	subscriptions = {}
	$.fn.subscribe = (channel, cb) ->

		subscriptions[channel] ?= []
		subscriptions[channel].push
			'subscriber': @
			'cb': cb
		return @

	# Go through all subscriptions on a data channel,
	# and run the callback with the data supplied.
	# If the callback does not return false, also refresh the subscriber plugin.
	# FIXME: Skip callback if publisher is subscriber.
	pubHistory = [] # For debugging.
	$.fn.publish = (channel, data) ->

		return @ if subscriptions[channel] is undefined

#		repeat subscriptions[channel].length, (n) =>
#			sub = subscriptions[channel][n]
#			return unless sub.plugin

		for sub in subscriptions[channel] when sub.subscriber
			unless $.contains document, sub.subscriber.get(0)
				sub.subscriber = null
				continue # was return
			# If publisher is also subscriber, skip processing this channel's data.
			continue if sub.subscriber.prop('id') is @.prop('id')
			ret = if data? then sub.cb.apply sub.subscriber, data else sub.cb.apply sub.subscriber
			sub.subscriber.trigger '_', [ret] if ret isnt false
			#pubHistory.push "${@prop('id')} > $channel > ${sub.subscriber.prop('id')}"

		return @

	# Bind an element to the refresh event, or trigger a refresh. Once the handler
	# has been run, bubble the event upwards with the action 'show_tab'.
	$.fn.refresh = (cb) ->

		if typeof cb is 'function'
			@bind '_', (e, action) ->
				# Don't give the event object to the handler.
				ret = cb.apply $(@), Array.prototype.slice.call(arguments, 1) if action isnt 'show_tab'
				return false if ret is false
				$(@).parent().trigger '_', ['show_tab'] if e.isPropagationStopped()
		else
			@triggerHandler '_'
		return @

	# Provide a set of behaviours to control visual display of elements being loaded with
	# data from ajax calls.
	$.fn.loading = (x) ->
		@find('.failed').remove()
		#@append $('<span class="loading">').text "Loading #{x}..."
		@append $('<span>').addClass('loading').text "Loading #{x}..."
	$.fn.succeeded = ->
		@find('.loading').remove()
		return @
	$.fn.failed = (x) ->
		if x
			@find('.loading, .failed').remove()
			@append $('<span>').addClass('failed').text "Failed to get #{x}. Try again."
		else
			@find('.failed').length

	# Bind an ajax request for an evergreen service to a jQuery object.
	# Show a message to user while loading.
	# Call the ok callback with the result in the context of the jQuery object.
	# Otherwise, show a failed message if the request failed.

	@.isEmpty = isEmpty = (o) -> not (1 for p of o).length

	$.fn.openils = (usage, svc) ->

		ok = ->
		failed_or_succeeded = (res) =>
			# FIXME: we want to fix eg.api so that no ilsevent objects are returned to this level.
			if res.ilsevent? or res instanceof Error
				@failed usage
			else
				ok.call @succeeded(), res

		@loading usage
		switch arguments.length
			when 4
				ok = arguments[3]
				d = eg.openils svc, arguments[2], failed_or_succeeded
			when 3
				ok = arguments[2]
				d = eg.openils svc, failed_or_succeeded
			else
				return @failed(usage).publish 'prompt', ['Client error', "Malformed service method #{svc}"]
		# eg.openils() normally returns a deferred object, not an array.
		@failed(usage).publish 'prompt', ['Client error', "Undefined service method #{svc}"] if $.isArray d
		return @

	$.fn.parallel = (usage, o, ok) ->
		@loading usage
		parallel(o).next (x) =>
			for k of o when x.k instanceof Error
				return @failed usage
			ok.call @succeeded(), x
		.error =>
			@failed usage unless @failed() # Show failure message only once.

	return @
