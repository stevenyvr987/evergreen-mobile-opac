# load_spinner.coffee
#
# Shows an spinner graphic upon an ajax start event,
# but hides it upon an ajax stop or error event.
#

module 'load_spinner', imports('plugin'), ->

	$.fn.load_spinner = (o) ->

		@plugin('load_spinner')
		.refresh refresh = ->
			$.mobile.hidePageLoadingMsg()
			return false
		.ajaxStop(refresh)
		.ajaxError(refresh)
		.ajaxStart ->
			$.mobile.showPageLoadingMsg()
			return false

		# FIXME: if user presses esc key to force loading to stop, the spinner stays on screen.
		# following keydown event is not caught.
#		$(document).keydown (e) ->
#			$image.hide() if e.keyCode is 27

		return @
