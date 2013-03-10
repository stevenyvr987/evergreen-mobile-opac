# Define a handler for the mobileinit event to customize some jQuery Mobile
# settings.
(($) ->
	$(document).one 'mobileinit', ->
		# Do not inset collapsible content to maximize the use of screen width
		$.mobile.collapsible.prototype.options.inset = false
		# Allow placeholder menu items to be selectable
		$.mobile.selectmenu.prototype.options.hidePlaceholderMenuItems = false
		# We disable jQM's ajax mechanism since we are using the one in jQuery.
		$.mobile.ajaxEnabled = false
		#console.log "in mobileinit ajaxEnabled is #{$.mobile.ajaxEnabled}"
)(jQuery)
