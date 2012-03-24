# We define a module that contains a jQuery plugin
# to show the status of a user when the user is logged in.
# The prepatory work to build user status
# will be delayed until the user has logged in.
#
# The plugin will show or hide user status upon login or logout.
# User status will be shown as a collapsible set of summary lines:
#
# 1. the amount of fines owed
# 2. the number of items checked out
# 3. the number of items on hold
# 4. the number of bookbags created (not currently implemented)
#
# The plugin will refresh a summary line and its details
# upon the user expanding the summary line.
# The plugin will empty a summary line details
# upon the user collapsing the summary line.
#
# If a summary line is expanded,
# the plugin will refresh or empty a summary line's details upon login or logout.
#
# If the plugin receives *refresh*, it will refresh all summary lines.

define [
	'jquery'
	'eg/eg_api'
	'eg/auth'
	'template'
	'plugin'
	'account/fines'
	'account/checkouts'
	'account/holds'
], ($, eg, auth, _) ->

	# ***
	# Each summary line is implemented by a template,
	# and a refresh function that will make the relevant service call
	# to get data values and instantiate the template with them.

	tpl_fines_summary = _.template '''
	$<%= nf %> fines owing
	'''
	refresh_fines_summary = ->
		$('#fines_summary').openils 'fines summary', 'actor.user.fines.summary.authoritative', (o) ->
			$('.summary_line', @).text tpl_fines_summary
				nf: nf = o.balance_owed
		return false

	tpl_checkouts_summary = _.template '''
	<%= nco %> items checked out,
	<%= nod %> overdue,
	<%= nxx %> other items
	'''
	refresh_checkouts_summary = ->
		$('#checkouts_summary').openils 'checkouts summary', 'actor.user.checked_out.count.authoritative', (o) ->
			$('.summary_line', @).text tpl_checkouts_summary
				nco: nco = o.out
				nod: nod = o.overdue
				nxx: nxx = o.total - nco - nod
		return false

	tpl_holds_summary = _.template '''
	<%= nh %> items on hold
	'''
	refresh_holds_summary = ->
		$('#holds_summary').openils 'holds summary', 'circ.holds.id_list.retrieve.authoritative', (o) ->
			$('.summary_line', @).text tpl_holds_summary
				nh: nh = o.length
		return false

	tpl_bookbags_summary = _.template '''
	<%= nbb %> bookbags created
	'''
	refresh_bookbags_summary = ->
		$('#bookbags_summary').openils 'bookbags summary', 'actor.container.retrieve_by_class', (o) ->
			$('.summary_line', @).text tpl_bookbags_summary
				nbb: nbb = o.length
		return false

	# ***
	# Define a function to refresh all summary lines.
	refresh_all = ->
		refresh_fines_summary()
		refresh_checkouts_summary()
		refresh_holds_summary()


	# ***
	# Define a jQuery plugin to show account summary lines.
	$.fn.acct_summary = ->
		return @ if @plugin()
		@plugin('acct_summary')
		# > FIXME:
		# The main div may be inadvertently shown after a session timeout.
		# This is because the plugin does not contain summary bars.
		# receives logout_event, which is session timeout,
		# and proceeds to empty div but div is always empty.

		# Upon applying the plugin,
		# we will further apply account detail plugins to their containers.
		$('#account_fines').fines()
		$('#account_checkouts').checkouts()
		$('#account_holds').holds()

		# We will refresh the summary lines if the user is already logged in,
		# otherwise, we will retrieve a session object before we refresh.
		if auth.logged_in()
			refresh_all()
		else
			@openils 'account summaries', 'auth.session.retrieve', refresh_all

		# Upon the user logging in,
		# we will show the summary lines and refresh their content.
		@subscribe 'login_event', =>
			$('.account_summary', @).show()
			refresh_all()
			return false
		# > FIXME:
		# The main module already subscribes this plugin to the login_event
		# when it dynamically loads this module.

		# Upon the user logging out, we will hide the summary lines.
		.subscribe 'logout_event', =>
			$('.account_summary', @).hide()
			return false

		# Upon receiving a notice to a summary line, we will refresh it.
		.subscribe('fines_summary', refresh_fines_summary)
		.subscribe('checkouts_summary', refresh_checkouts_summary)
		.subscribe('holds_summary', refresh_holds_summary)
		.subscribe('bookbags_summary', refresh_bookbags_summary)

		# Upon a plugin refresh, we will refresh all summary lines.
		.refresh refresh_all

		$('.account_summary', @)

		# Upon the user expanding a summary line,
		# we will refresh the line and its inner plugins.
		.live 'expand', (e, ui) ->
			$(@).publish $('h3', @).prop 'id' # The h3 element id is the name of the data channel to publish on
			$('.plugin', @).refresh()
			return false

		# Upon the user collapsing a summary line,
		# we will empty its inner plugin content.
		.live 'collapse', (e, ui) ->
			$('.plugin', @).empty()
			return false

		# Upon the user logging in,
		# we will refresh a summary line's inner plugin content if the summary line is not collapsed.
		.subscribe 'login_event', ->
			$(ps).refresh() for ps in $('.plugin', @) when $(ps).closest('.ui-collapsible-content').prop('aria-hidden') is 'false'
			return false

		# Upon the user logging out,
		# we will empty a summary line's inner plugin content if the summary line is not collapsed.
		.subscribe 'logout_event', ->
			$(ps).empty() for ps in $('.plugin', @) when $(ps).closest('.ui-collapsible-content').prop('aria-hidden') is 'false'
			return false

		return @
