# We define a module called 'load_spinner'.
define ['plugin'], -> (($) ->

	# The module defines a jQuery plugin to show or hide a spinner graphic.
	# It is actually a wrapper to use jQuery Mobile's 'page loading message' as the graphic.
	$.fn.load_spinner = ->

		show = -> $.mobile.showPageLoadingMsg()

		hide = -> $.mobile.hidePageLoadingMsg()

		# We show the spinner upon an ajax start event, and hide it upon an
		# ajax stop or an ajax error event.
		$(document)
			.ajaxStart(show)
			.ajaxStop(hide)
			.ajaxError(hide)

		@plugin('load_spinner')
			.refresh(hide)

	# > FIXME: if the user presses the esc key to force loading to stop,
	# we ought to hide the spinner.
)(jQuery)
