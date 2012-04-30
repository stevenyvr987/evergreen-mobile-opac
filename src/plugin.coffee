# We define a module called _plugin_.
# The module defines a variety of custom jQuery methods
# that can be applied to custom-defined plugins.

define ['jquery'], ($) ->

	# ### Define a _plugin_ method
	# Use the method to label custom plugins with a given classname
	# or to check if custom plugins have been so labelled.
	$.fn.plugin = (x) ->
		if x then @addClass "plugin #{x}" else @hasClass "plugin"


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
