# The mobile OPAC uses the _jMod_ library for defining modules.
# We configure the file path where _jMod_ can expect to find modules.
jMod.config path: 'js'

# The mobile OPAC uses _jQuery Mobile_.
# We customize some jQM options.
jQuery.mobile.selectmenu.prototype.options.hidePlaceholderMenuItems = false
# We disable jQM's ajax mechanism since we are using the one in jQuery.
jQuery.mobile.ajaxEnabled = false

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


# We define the main module.
module 'mobile_opac', imports(
	'messages2'
	'load_spinner'
	'login_bar'
), ->

	# Upon document is ready...
	jQuery ($) ->

		# We will prepare a container for displaying error or progress messages.
		$('#messages').messages()

		# We will apply a load spinner to the body,
		# which will indicate that data is being transferred across the network.
		$('#main').load_spinner()

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
			thunk imports('account.summary'), => @acct_summary() unless @plugin()
			return false

		# Upon starting an OPAC search for first time,
		# we will load and apply the search bar and result summary plugins.
		# The search bar will be customized by values found in _window.settings_.
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
			return # need to bubble up click event for jQM
		$('#opac_search').click ->
			toggle = if $(@).is(':visible') then 'collapse' else 'expand'
			$('.account_summary').each -> $(@).trigger toggle
			return # need to bubble up click event for jQM

		return
