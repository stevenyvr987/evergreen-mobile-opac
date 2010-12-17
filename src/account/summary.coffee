module 'account.account_summary', imports( 'eg.eg_api', 'plugin' ), (eg) ->

	$.fn.account_summary = ->
		@plugin('account_summary').append $('<div>').acct_summary()
		@refresh ->
			@publish 'userid', [eg.auth.session.user.id] if eg.auth.session?.user?
			return false


module 'account.summary', imports(
	'eg.eg_api'
	'template'
	'plugin'
	'account.fines'
	'account.checkouts'
	'account.holds'
), (eg, _) ->

	tpl_fines_summary = _.template '''
	$<%= nf %> fines owing
	'''
	refresh_fines_summary = ->
		$('#fines_summary').openils 'fines summary', 'actor.user.fines.summary.authoritative', (o) ->
			@text tpl_fines_summary {
				nf:  nf = o.balance_owed
			}
		return false

	tpl_checkouts_summary = _.template '''
	<%= nco %> items checked out,
	<%= nod %> overdue,
	<%= nxx %> other items
	'''
	refresh_checkouts_summary = ->
		$('#checkouts_summary').openils 'checkouts summary', 'actor.user.checked_out.count.authoritative', (o) ->
			@text tpl_checkouts_summary {
				nco: nco = o.out
				nod: nod = o.overdue
				nxx: nxx = o.total - nco - nod
			}
		return false

	tpl_holds_summary = _.template '''
	<%= nh %> items on hold
	'''
	refresh_holds_summary = ->
		$('#holds_summary').openils 'holds summary', 'circ.holds.id_list.retrieve.authoritative', (o) ->
			@text tpl_holds_summary {
				nh:  nh = o.length
			}
		return false

	tpl_bookbags_summary = _.template '''
	<%= nbb %> bookbags created
	'''
	refresh_bookbags_summary = ->
		$('#bookbags_summary').openils 'bookbags summary', 'actor.container.retrieve_by_class', (o) ->
			@text tpl_bookbags_summary {
				nbb: nbb = o.length
			}
		return false

	refresh_all = ->
		refresh_fines_summary()
		refresh_checkouts_summary()
		refresh_holds_summary()
		#refresh_bookbags_summary()


	$.fn.acct_summary = ->

		$('#account_fines').fines()
		$('#account_checkouts').checkouts()
		$('#account_holds').holds()

		# Do a first-time refresh of summary lines.
		if eg.logged_in()
			refresh_all()
		else
			@openils 'account summaries', 'auth.session.retrieve', refresh_all

		# FIXME: plugin does not contain summary bars.
		# receives logout_event, which is session timeout,
		# and proceeds to empty div but div is always empty.
		# The impact is that the main div is exposed after a session timeout.
		@plugin('acct_summary')

		.subscribe 'userid', (id) ->
			@refresh() if @is ':visible'
			return false

		# FIXME: the main module subscribes this plugin to login_event already.
		# We must do it there because it dynamically loads this module.
		.subscribe('login_event', refresh_all)

		.subscribe 'logout_event', ->
			# FIXME: following sequence uses IDs, which breaks the rule
			# that a plugin should not know about things outside its boundary.
			$('#account_summary .accordion.on').click()
			$('#fines_summary').empty()
			$('#checkouts_summary').empty()
			$('#holds_summary').empty()
			#$('#bookbags_summary').empty()
			return false

		.subscribe('fines_summary', refresh_fines_summary)
		.subscribe('checkouts_summary', refresh_checkouts_summary)
		.subscribe('holds_summary', refresh_holds_summary)
		.subscribe('bookbags_summary', refresh_bookbags_summary)
		.refresh refresh_all

			# Guard against login process not finished before attempting to get account summaries.
#			if eg.logged_in()
#				refresh.call @
#			else
#				@openils 'account summaries', 'auth.session.retrieve', => refresh.call @
