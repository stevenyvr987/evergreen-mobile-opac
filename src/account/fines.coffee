# fines.coffee
#
# List any fines the user has to pay.

module 'account.account_fines', imports('eg.eg_api', 'plugin'), (eg) ->
	$.fn.account_fines = ->
		$('<div>').fines().appendTo @
		@refresh ->
			@publish 'userid', [eg.auth.session.user.id] if eg.auth.session?.user?
			return false


module 'account.fines', imports(
	'eg.eg_api'
	'template'
	'plugin'
), (eg, _) ->

	tpl_info_line = _.template '''
	<div class="my_fine" id=fine_id_"<%= fine_id %>">
		<span>$<%= owed %></span>
		<span><%= type %></span>
		<span><%= date %></span>
		<span><%= time %></span>
		<span><%= note %></span>
	</div>
	'''

	show_info_line = (mbts) ->
		@append tpl_info_line {
			fine_id: x.id
			owed: x.balance_owed
			type: x.last_billing_type
			date: x.last_billing_ts.slice 0, 10
			time: x.last_billing_ts.slice 11, 16
			note: x.last_billing_note
		} for x in mbts
		return

	$.fn.fines = ->

		@plugin('acct_fines')
		.append( $x = $('<form>') )

		.subscribe 'userid', ->
			@refresh() if @is ':visible'
			return false

		.subscribe 'logout_event', ->
			$x.empty()
			return false

		.refresh ->
			$x.empty().openils 'fines details', 'actor.user.transactions.have_charge.fleshed', show_info_line
			return false

		return @
