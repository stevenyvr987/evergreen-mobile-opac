# We define a module that contains a jQuery plugin
# to list fines or bills the user has to pay.
# The plugin will refresh the list upon receiving *refresh*.
# Currently, the plugin will not enable the user to interactively select bills and pay them.

module 'account.fines', imports(
	'eg.eg_api'
	'template'
	'plugin'
), (eg, _) ->


	# ***
	# Define the outer container of the list of bills.
	# The container will use a forms element
	# in order to prepare for future interactivity.
	tpl_list = '''
	<form>
		<div data-role="fieldcontain">
			<fieldset data-role="controlgroup" />
		</div>
	</form>
	'''

	# Define the template of a bill.
	# The outer container will be identified by *bill_id*.
	# Internally, the details of a bill will be shown in a status line
	# and will be accompanied by a checkbox.
	# If the user selects the checkbox, it will set *bill_id* for *value*.
	tpl_bill = _.template '''
	<div id="bill_id_<%= bill_id %>">
		<input type="checkbox" name="bill_id" value="<%= bill_id %>" id="checkbox_<%= bill_id %>" />
		<label for="checkbox_<%= bill_id %>">
			<span class="status_line">
				<span>$<%= owed %></span>
				<span><%= type %></span>
				<br />
				<span><%= date %></span>
				<span><%= note %></span>
			</span>
		</label>
	</div>
	'''


	# ***
	# Define a function to refresh the bills list given an *mbts* object.
	# A compoment of a bill is its datestamp, which we convert into MMDDYY format. 
	pad = (x) -> if x < 10 then '0' + x else x
	mmddyy = (x) ->
		"#{pad x.getMonth() + 1}/#{pad x.getDate()}/#{pad x.getFullYear()}"
	refresh_list = (mbts) ->
		@append tpl_bill {
			bill_id: x.id
			owed: x.balance_owed
			type: x.last_billing_type
			date: mmddyy x.last_billing_ts
			note: x.last_billing_note
		} for x in mbts
		@trigger 'create'
		return


	# ***
	# Define a jQuery plugin for showing the bills list.
	$.fn.fines = ->
		$plugin = @plugin('acct_fines').trigger('create')

		# If the plugin receives *refresh*,
		# we will recreate the list
		# and make a service call to try to get new data to show in the list.
		.refresh ->
			@html(tpl_list).trigger 'create'
			$('fieldset', @)
			.openils 'fines details', 'actor.user.transactions.have_charge.fleshed', refresh_list
			return false

		return @
