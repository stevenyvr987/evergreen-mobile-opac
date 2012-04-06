require.config
	paths:
		jquery: 'http://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min'
		jqm:    'http://code.jquery.com/mobile/1.1.0-rc.1/jquery.mobile-1.1.0-rc.1.min'
		json2:  'http://ajax.cdnjs.com/ajax/libs/json2/20110223/json2'
		jsd:    'lib/jsdeferred'
		md5:    'lib/md5'
		jqm_sd: 'lib/jquery.mobile.simpledialog2'
		fmall:  'dojo/fieldmapper/fmall'
		fmd:    'eg/fm_datatypes'

	priority: ['jquery', 'jqm', 'base']

require [
	'jquery', 'jqm', 'base'
	'messages2', 'load_spinner', 'login_bar'
], ($) ->

	# The mobile OPAC uses _jQuery Mobile_.
	# We customize some jQM options.
	$.mobile.selectmenu.prototype.options.hidePlaceholderMenuItems = false
	# We disable jQM's ajax mechanism since we are using the one in jQuery.
	$.mobile.ajaxEnabled = false

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

	$ ->
		# We will apply a load spinner to the body.  The load spinner will
		# indicate that data is being transferred across the network.
		$('body').load_spinner()

		# We will apply a message box.  The message box will display error or
		# progress messages.
		$('#messages').messages()

		# We will prepare a container for enabling the user to log in or log out.
		$('#login_bar').login_bar()

		# We will hide account summary lines,
		# because the user is not logged in upon startup.
		$('.account_summary').hide()

		# Upon user login, we will show account summary lines.
		$('#account_summary').subscribe 'login_event', ->
			$('.account_summary', @).show()
			# We will also load and apply the account summary plugin
			# if it hasn't been applied before.
			require ['account/summary'], => @acct_summary()
			return false

		# Upon starting an OPAC search for first time, we will load and apply
		# the opac search page.
		$('#opac_search').one 'click', ->
			require ['opac/search'], => $(@).opac_search()
			return # need to bubble up click event for jQM

		# Whenever the user expands the search bar,
		# my account summary bars should collapse, and vice versa.
		# This means the search bar acts as part of the collapsible set of summary bars,
		# even though it is not located inside the container
		# that defines the summary bars as a collapsible set.
		$('.account_summary').click ->
			toggle = if $(@).is(':visible') then 'collapse' else 'expand'
			$('#opac_search').trigger toggle
			return # need to bubble up click event for jQM
		$('#opac_search').click ->
			toggle = if $(@).is(':visible') then 'collapse' else 'expand'
			$('.account_summary').each -> $(@).trigger toggle
			return # need to bubble up click event for jQM

		return
