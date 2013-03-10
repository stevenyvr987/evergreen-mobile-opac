# We define a module called 'load_spinner'.
define ['plugin'], -> (($) ->

	# The module defines a jQuery plugin to show or hide a spinner graphic.
	# It is actually a wrapper to use jQuery Mobile's 'page loading message' as the graphic.
	$.fn.load_spinner = () ->

		@plugin('load_spinner')

		# We show the spinner upon an ajax start event,
		.ajaxStart ->
			$.mobile.showPageLoadingMsg()
			return false

		.refresh refresh = ->
			$.mobile.hidePageLoadingMsg()
			return false

		# and hide the spinner upon an ajax stop
		.ajaxStop(refresh)
		# or an ajax error event.
		.ajaxError(refresh)

	# > FIXME: if the user presses the esc key to force loading to stop,
	# we ought to hide the spinner.
)(jQuery)
