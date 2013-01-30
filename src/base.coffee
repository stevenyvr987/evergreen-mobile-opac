# Define a placeholder module to require the common modules used across web
# pages.

define [
	'settings'
	'json2'
	'jsd'
	'plugin'
	'publish'
	'template'
], (rc) ->

	# We will prepare Google Analytics tracking if an account ID is specified.
	require(['jquery_ga'], -> $.ga rc.ga_uid) if rc.ga_uid?

	# The mobile OPAC uses _jQuery Mobile_.
	# We define a handler to customize some jQM options.
	# FIXME: mobileinit event is not triggering!
	$(document).bind 'mobileinit', ->
		$.extend $.mobile,
			# Do not inset collapsible content to maximize the use of screen width
			'collapsible.prototype.options.inset': false
			'selectmenu.prototype.options.hidePlaceholderMenuItems': false
			# We disable jQM's ajax mechanism since we are using the one in jQuery.
			'ajaxEnabled': false

	# The mobile OPAC uses _JSDeferred_ to manage deferrments.
	# We initialize the service for use.
	Deferred.define()
	# >For debugging: catch errors thrown by Deferred callbacks and show them as alert messages.
	# Deferred.onerror = (e) -> alert e + "\n" + JSON.stringify e, null, '  '

	# The mobile OPAC can be passed run-time parameters in the query string.
	# We parse it for any such parameters and make them available in _window.query_.
	( (q) ->
		return unless q.length
		query = {}
		d = (x) -> decodeURIComponent x.replace /\+/g, ' '
		r = /([^&=]+)=?([^&]*)/g
		while x = r.exec q
			query[d x[1]] = d x[2]
		window['query'] = query
	)(window.location.search.substring(1))
	return
