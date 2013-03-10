# We define a module that contains a jQuery plugin
# to list fines or bills the user has to pay.
# The plugin will refresh the list upon receiving *refresh*.
# Currently, the plugin will not enable the user to interactively select bills and pay them.

define [
	'eg/eg_api'
	'template'
	'plugin'
], (eg, _) -> (($) ->

	# ***
	# Define the outer container of the list of bills.
	# The container will use a forms element
	# in order to prepare for future interactivity.
	tpl_bill_list = '''
	<form>
		<fieldset data-role="controlgroup" />
		<div data-role="controlgroup" data-type="horizontal">
			<!--<span><button name="payment" type="button">Pay selected fines</button></span>-->
			<span><button name="history" type="button">See payments</button></span>
		</div>
	</form>
	'''

	# Define the template of a bill.
	# The outer container will be identified by *bill_id*.
	# Internally, the details of a bill will be shown in a status line
	# and will be accompanied by a checkbox.
	# If the user selects the checkbox, it will set *bill_id* for *value*.
	tpl_bill = _.template '''
	<input type="checkbox" checked name="bill_id" value="<%= bill_id %>" id="checkbox_<%= bill_id %>" />
	<label for="checkbox_<%= bill_id %>">
		<span class="status_line">
			<span>$<%= owed %></span>
			<span><%= type %></span>
			<br />
			<span><%= date %></span>
			<span><%= note %></span>
		</span>
	</label>
	'''

	tpl_payment_list = '''
	<form>
		<fieldset data-role="controlgroup" />
		<div data-role="controlgroup" data-type="horizontal">
			<span><button name="bills" type="button">See fines</button></span>
			<span><button name="print" type="button">Print selected payments</button></span>
			<span><button name="email" type="button">Email selected payments</button></span>
		</div>
	</form>
	'''
	tpl_payment = _.template '''
	<input type="checkbox" name="payment_id" value="<%= payment_id %>" id="checkbox_<%= payment_id %>" />
	<label for="checkbox_<%= payment_id %>">
		<span class="status_line">
			<span>$<%= owed %></span>
			<span><%= type %></span>
			<br />
			<span><%= date %></span>
			<span><%= note %></span>
		</span>
	</label>
	'''

	# ***
	# Define a function to convert a datestamp into MMDDYY format.
	pad = (x) -> if x < 10 then '0' + x else x
	mmddyy = (x) -> "#{pad x.getMonth() + 1}/#{pad x.getDate()}/#{pad x.getFullYear()}"

	$plugin = {}

	refresh_bill_list = ->
		@html(tpl_bill_list) # replace with a fresh template
		.trigger('create') # recreate it using jQM plugins
		.find('fieldset')
		.openils 'fines details', 'actor.user.transactions.have_charge.fleshed', (data) ->
			# Upon getting an *mbts* object, we will refresh the bills
			# list.  A compoment of a bill is its datestamp, which we
			# will convert into MMDDYY format. 
			for o in data
				mbts = o.mbts
				mvr = o.mvr
				note = if mbts.xact_type is 'circulation' then "'#{mvr.title}' by #{mvr.author}" else mbts.last_billing_note
				@append tpl_bill
					bill_id: mbts.id
					owed: mbts.balance_owed
					type: mbts.last_billing_type
					date: mmddyy mbts.last_billing_ts
					note: note
			# After adding all list items, we trigger the top container
			# to ensure that all jQM plugins contained within are
			# triggered.
			$plugin.trigger 'create'
		return false

	refresh_payment_list = ->
		@html(tpl_payment_list)
		.trigger('create')
		.find('fieldset')
		.openils 'payment details', 'actor.user.payments.retrieve', (data) ->
			for o in data
				mp = o.mp
				note = if o.xact_type is 'circulation' then "'#{o.title}'" else mp.note
				payment = tpl_payment
					payment_id: mp.id
					owed: mp.amount
					type: o.last_billing_type
					date: mmddyy mp.payment_ts
					note: note
				@append payment
			$plugin.trigger 'create'
		return false

	# ***
	# Define a jQuery plugin for showing the bills list.
	$.fn.fines = ->
		$plugin = @plugin('acct_fines').trigger('create')

		# If the plugin receives *refresh*, we will recreate the list and make
		# a service call to try to get new data to show in the list.
		@refresh ->
			refresh_bill_list.apply @

		.on 'click', '[name="bills"]', =>
			refresh_bill_list.apply @

		.on 'click', '[name="history"]', =>
			refresh_payment_list.apply @

		.on 'click', '[name="payment"]', ->
			eg.openils 'circ.money.payment', {}, (r) ->
				x = r
			return false

		.on 'click', '[name="email"]', =>
			ids = []
			ids.push Number(id.value) for id in $('[name="payment_id"]:checked', @)
			switch nids = ids.length
				when 0
					@publish 'notice', ['No payments were selected']
				when 1
					eg.openils 'circ.money.payment_receipt.email', ids, (e) =>
						@publish 'notice', ['Payment receipt emailed.']
						return
				else
					eg.openils 'circ.money.payment_receipt.email', ids, (e) =>
						@publish 'notice', ["#{nids} Payment receipts emailed."]
						return
			return false

		.on 'click', '[name="print"]', =>
			ids = []
			ids.push Number(id.value) for id in $('[name="payment_id"]:checked', @)
			switch nids = ids.length
				when 0
					@publish 'notice', ['No payments were selected']
				else
					eg.openils 'circ.money.payment_receipt.print', ids, (atev) ->
						receipt = atev.template_output.data
						$.mobile.changePage $('#payment_receipt').find('.content').html(receipt).end()
						return
			return false
		return @
)(jQuery)
