# We define a module to contain a jQuery plugin
# to list items the user has checked out
# or in other unfinished circulation statuses.
# Interactively, the plugin will behave as follows.
#
# * Respond to submit events fron the user to renew checked out items
# * Refresh the list upon receiving *refresh*
# * Publish *checkouts_summary* to synchronize its summary line

define [
	'jquery'
	'eg/eg_api'
	'template'
	'plugin'
], ($, eg, _) ->


	# ***
	# Define the container of content, a list of items.
	# The list will be built as an interactive form
	# containing a set of input fields,
	# accompanied by submit buttons to renew a group of selected items.
	content = '''
	<form>
		<fieldset data-role="controlgroup" />
		<div data-role="controlgroup" data-type="horizontal">
			<span class="renew some"><button type="submit">Renew selected items</button></span>
			<span class="renew all"><button type="submit">Renew all</button></span>
		</div>
	</form>
	'''

	# Define the template for displaying an item.
	# The outer container will be identified by *circ_id*.
	# Details of an item will be shown in an *info_line* and a *status_line*.
	# An item can be in one of several circulation states
	# and the status line will normally show it,
	# but if the item is checked out, which is the majority case,
	# the status line will omit showing the state.
	# The item will be accompanied by a checkbox.
	# If the user selects the checkbox, it will set *circ_id* for *value*.
	tpl_item = (type) ->
		x = if type is 'out'
			'''
			<div class="my_checkout" id="circ_id_<%= circ_id %>">
				<input type="checkbox" name="copy_id" value="<%= circ_id %>" id="checkbox_<%= circ_id %>" />
				<label for="checkbox_<%= circ_id %>">
					<span class="info_line">
						<span class="title" />
						<span class="types" />
						<br />
						<span class="author" />
					</span>
					<br />
					<span class="status_line">
						Due date <span class="due_date" />
						Renews left <span class="remaining_renewals" />
					</span>
				</label>
			</div>
			'''
		else
			'''
			<div class="my_checkout" id="circ_id_<%= circ_id %>">
				<input type="checkbox" name="copy_id" value="<%= circ_id %>" id="checkbox_<%= circ_id %>" />
				<label for="checkbox_<%= circ_id %>">
					<span class="info_line">
						<span class="title" />
						<span class="types" />
						<br />
						<span class="author" />
					</span>
					<br />
					<span class="status_line">
						<span class="copy_status"><%= circ_type %></span>
						Due date <span class="due_date" />
						Renews left <span class="remaining_renewals" />
					</span>
				</label>
			</div>
			'''
		_.template x


	# ***
	# Define a function to refresh the *info_line* given an *mvr* object and a context.
	show_info_line = (mvr) ->
		$('.title', @).text mvr.title if mvr.title
		$('.author', @).text "#{mvr.author}" if mvr.author
		$('.types', @).text "#{(mvr.types_of_resource).join ', '}" if mvr.types_of_resource

	# Define a function to refresh the *status_line* given a *circ* object and a context.
	# One of the compoments of the status line is the due date,
	# which we will convert into MMDDYY format. 
	pad = (x) -> if x < 10 then '0' + x else x
	mmddyy = (x) ->
		"#{pad x.getMonth() + 1}/#{pad x.getDate()}/#{pad x.getFullYear()}"
	show_status_line = (circ) ->
		$('.due_date', @).text mmddyy circ.due_date
		$('.remaining_renewals', @).text circ.renewal_remaining
		$('input:checkbox', @).val circ.target_copy


	# ***
	# Define a function to make a service call to try to renew an item given a copy ID.
	$plugin = {}
	renew = (xid) ->
		eg.openils 'circ.renew', parseInt(xid), (result) ->
			# >FIXME:
			# If *result.desc* indicates failure,
			# we will have *result.circ*, *result.copy*, and *result.record* objects on hand.
			# Using their information, we could refresh individual status lines
			# rather than refreshing the entire list.
			$plugin.refresh().publish 'account.checkouts_summary'


	# ***
	# Define the jQuery plugin to show and control a list of items.
	$.fn.checkouts = ->
		$plugin = @plugin('acct_checkouts').trigger('create')

		# Upon receiving *refresh*,
		# we will recreate and refresh the list.
		@refresh ->
			@html(content).trigger 'create'

			# We will hide buttons until they are needed.
			$renew_some = $('.renew.some', @).hide()
			$renew_all = $('.renew.all', @).hide()

			# We will make the relevant set of service calls to try to get checkout information.
			#
			# 1. Get summary object for the user, which lists circ IDs that are hashed by circ type
			# 2. Get the circ object for each ID
			# 3. Get the mvr object for target copy ID
			#
			# We will progressively populate the list as data become available.
			# Moreover, we will modify the visibility of the list and its buttons
			# according to the circ status.
			$('fieldset', @).openils 'checkout details', 'actor.user.checked_out.authoritative', (co) ->
				$plugin.publish 'account.items_checked_out', [co]
				for type, checkouts of co
					for circ_id in checkouts

						@prepend $item = $ (tpl_item type)
							circ_id: circ_id
							circ_type: type

						do (type, $item) ->
							$('.status_line', $item).openils "checkout status for ##{circ_id}", 'circ.retrieve.authoritative', circ_id, (circ) ->
								show_status_line.call $item, circ
								$('.info_line', $item).openils "title info for ##{circ.target_copy}", 'search.biblio.mods_from_copy', circ.target_copy, (mvr) ->
									show_info_line.call $item, mvr

								# * Emphasize overdue items
								if type isnt 'out'
									$('input, .info_line, .status_line', $item).prop 'data-theme', 'e'
								# * Disable checkboxes of non-renewable items
								if circ.renewal_remaining is 0
									$item.find(':checkbox').prop 'disabled', true
								# * Show only relevant submit buttons
								if type is 'out' and circ.renewal_remaining > 0
									if $renew_all.is ':visible' then $renew_some.show() else $renew_all.show()
								$plugin.trigger 'create'
			return false

		# Upon the user clicking the *renew some* button,
		# we will find the selected DOM elements
		# and renew the related items asynchronously.
		# We also will refresh the list.
		# If the user clicked the button without making a selection,
		# we will publish a notice instead.
		@on 'click', '.renew.some', ->
			xids = $(@).closest('form').serializeArray()
			if xids.length
				renew xid.value for xid in xids
			else
				$(@).publish 'notice', ['Nothing was done because no items were selected.']
			return false

		# Upon the user clicking the *renew all* button,
		# we do as above, except the details of finding items differ.
		# Here, we will find the set as jQuery objects.
		@on 'click', '.renew.all', ->
			$xs = $(@).closest('form').find('input:checkbox:enabled')
			if $xs.length
				$xs.each -> renew $(@).val()
			else
				$(@).publish 'notice', ['Nothing was done because no items can be renewed.']
			return false
