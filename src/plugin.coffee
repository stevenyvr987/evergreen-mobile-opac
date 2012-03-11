# We define a module called _plugin_.
# The module defines a variety of custom jQuery methods
# that can be applied to custom-defined plugins.

define [
	'jquery'
	'eg/eg_api'
], ($, eg) ->

	# ### Define a _plugin_ method
	# Use the method to label custom plugins with a given classname
	# or to check if custom plugins have been so labelled.
	$.fn.plugin = (x) ->
		if x then @addClass "plugin #{x}" else @hasClass "plugin"


	# ### Define a _subscribe_ method
	# Use the method to subscribe custom plugins to a given data channel.
	subscriptions = {}
	$.fn.subscribe = (channel, cb) ->
		# Subscriptions will be stored
		# as a pair of plugin and callback objects
		# under the channel name.
		subscriptions[channel] ?= []
		subscriptions[channel].push
			'subscriber': @
			'cb': cb
		return @

	# ### Define a _publish_ method
	# Use the method to enable custom plugins
	# to publish a given data object to a given data channel.
	# The callbacks for all subscriptions on the data channel
	# will be applied to the subscribers with the given data object.
	$.fn.publish = (channel, data) ->
		return @ if subscriptions[channel] is undefined
		for sub in subscriptions[channel] when sub.subscriber
			unless $.contains document, sub.subscriber.get(0)
				sub.subscriber = null
				continue
			# If the publisher is also the subscriber, we will not process this channel's data.
			# > FIXME: unfortunately, plugins that do not supply an ID won't
			# benefit from this piece of logic.
			continue if sub.subscriber.prop('id') is @.prop('id')
			ret = if data? then sub.cb.apply sub.subscriber, data else sub.cb.apply sub.subscriber
			# If the callback does not return false, we will refresh the subscriber plugin.
			sub.subscriber.trigger '_', [ret] if ret isnt false

			# Log a signature on the console log to indicate who published what to who.
			# It's best to comment this line out before deploying for production service.
			#console.log @, (if ret is false then " |#{channel}> " else " |#{channel}>> "), sub.subscriber
		return @

	# >FIXME; the above publish/subscribe mechanism should be replaced by jQuery's custom event mechanism.


	# ### Define a _refresh_ method
	# Use the method to refresh the content of custom plugins.
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


	# ### Define helper methods for the _openils_ method

	# Define a method to remove existing loading or failed messages.
	$.fn.succeeded = ->
		@find('.loading, .failed').remove()
		return @

	# Define a method to replace loading or failed messages with a loading message.
	# The message can be tagged with a specific identifier.
	$.fn.loading = (tag) ->
		@succeeded()
		.append $('<span>').addClass('loading')
		.text "Loading #{tag}..."

	# Define a method to replace loading or failed messages with a failed message.
	# The message can be tagged with a specific identifier.
	# If no tag is given, the method can be used to check for the presence of a failed message.
	$.fn.failed = (tag) ->
		if tag
			@succeeded()
			.append $('<span>').addClass('failed')
			.text "Failed to get #{tag}. Try again."
		else
			@find('.failed').length

	# FIXME: Not used.
	@.isEmpty = isEmpty = (o) -> not (1 for p of o).length


	# ### Define a jQuery method of _eg.openils()_
	# Use the method to make service calls in the context of jQuery objects.
	# While waiting for the server response, the method will show a loading message to the user.
	# If the server responds, the method will call the service callback with the response.
	# Otherwise, the method will show a failed message to the user.
	$.fn.openils = (usage, svc) ->

		# Define the service callback,
		# which is specified in the 3rd or 4th position of the argument list.
		cb = ->

		# Define a helper to determine whether to call cb() or failed().
		succeeded_or_failed = (res) =>
			# >FIXME: we ought to fix eg.api so that the ilsevent object need not be used here.
			if res.ilsevent? or res instanceof Error
				@failed usage
			else
				cb.call @succeeded(), res

		@loading usage
		switch arguments.length
			when 4
				cb = arguments[3]
				d = eg.openils svc, arguments[2], succeeded_or_failed
			when 3
				cb = arguments[2]
				d = eg.openils svc, succeeded_or_failed
			else
				# We catch a possible coding error in the OPAC:
				# there should be at least three entries in the argument list.
				return @failed(usage).publish 'prompt', ['Client error', "Malformed service method #{svc}"]
		# We catch another possible coding error in the OPAC:
		# eg.openils() normally returns a deferred object, not an array.
		@failed(usage).publish 'prompt', ['Client error', "Undefined service method #{svc}"] if $.isArray d
		return @


	# ### Define a jQuery method of _parallel()_
	$.fn.parallel = (usage, o, cb) ->
		@loading usage
		parallel(o).next (res) =>
			for k of o when res.k instanceof Error
				return @failed usage
			cb.call @succeeded(), res
		.error =>
			@failed usage unless @failed() # Show failure message, but only once.

	return @
