# mobile_opac.coffee
#
# Entry way to the mobile OPAC application.


Deferred.define()

# For debugging: catch errors thrown by Deferred callbacks and show them as alert messages.
#Deferred.onerror = (e) -> alert e + "\n" + JSON.stringify e, null, '  '

# Define the base file path for modules
jMod.config { path: 'js' }


# Define some custom jQuery Mobile settings
#
jQuery.mobile.selectmenu.prototype.options.hidePlaceholderMenuItems = false
# Disable jQM's ajax mechanism since we are depending on the one in jQuery
jQuery.mobile.ajaxEnabled = false


# Do a one-time parse of any parameters in the query string.
# Make it available in window.query object.
( (q) ->
	return unless q.length
	query = {}
	d = (x) -> decodeURIComponent x.replace /\+/g, ' '
	r = /([^&=]+)=?([^&]*)/g
	while x = r.exec q
		query[d x[1]] = d x[2]
	window['query'] = query
)(window.location.search.substring(1))


module 'mobile_opac', imports(
	'messages'
	'load_spinner'
	'login_bar'
), ->

	jQuery ($) ->

		# Upon startup, hide account summary lines
		$('.account_summary').hide()

		# Upon user login, show account summary lines
		# and dynamically load and apply account summary plugin.
		$('#account_summary').subscribe 'login_event', ->
			$('.account_summary', @).show()
			thunk imports('account.summary'), => @acct_summary() unless @plugin()
			return false

		# Upon starting an OPAC search for first time,
		# dynamically load search bar and result summary plugins.
		$('#opac_search').one 'click', ->
			thunk imports('opac.search_bar'), -> $('#search_bar').search_bar(window.settings)
			thunk imports('opac.search_result'), -> $('#result_summary').result_summary()
			return # We allow the click event to bubble up to the accordion link.

		# Whenever the user expands the search bar,
		# my account summary bars should collapse, and vice versa.
		# This means the search bar acts as part of the collapsible set of summary bars,
		# even though it is not located inside the container
		# that defines the summary bars as a collapsible set.
		$('.account_summary').click ->
			toggle = if $(@).is(':visible') then 'collapse' else 'expand'
			$('#opac_search').trigger toggle
			return false
		$('#opac_search').click ->
			toggle = if $(@).is(':visible') then 'collapse' else 'expand'
			$('.account_summary').each -> $(@).trigger toggle
			return false

		# Prepare the following containers for immediate use.
		#
		# The login bar enables user to log in and out.
		$('#login_bar').login_bar()
		# Displays error messages and notices.
		$('#messages').messages()
		# Indicates data loading is occurring between client and server.
		$('body').load_spinner()
		return
