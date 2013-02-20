# Define a custom jQuery plugin to show the holding details of a possible hold target.
# The plugin will not react to any user events.

define [
	'jquery'
	'eg/eg_api'
	'eg/auth'
	'template'
	'opac/ou_tree'
	'plugin'
], ($, eg, auth, _, OU) ->

	format_callnumber = (cn) -> $.trim "#{cn[0]} #{cn[1]} #{cn[2]}"

	$.fn.holding_details = (title_id, search_ou, search_depth, status_names) ->

		holding_details = '''
		<div data-role="collapsible" data-collapsed="false" data-inset="false">
			<h3>Copies available for this title</h3>
			<ul data-role="listview" data-inset="false"></ul>
		</div>
		'''

		# Define a template and its accompanying function
		# to show details of a holding in a jQuery Mobile listview.
		# and to remove the empty parts of the template.
		# Details are specified by the given *holding_id* and *copy* object.
		tpl_holding_details = _.template '''
		<li class="holding status_line" id="<%= holding_id %>">
			<div>
				<span><span title="Circulating branch or library" class="value"><%= h.org_name %></span></span>
				<span> / <span title="Name of collection" class="value"><%= h.copylocation %></span></span>
				<span> / <span title="Call number" class="value"><%= callnumber %></span></span>
			</div>
			<span title="Copy status" class="copy_status">
				<span class="value"><%= h.Available %></span> available
			</span>
			<span title="Copy status" class="copy_status">
				<span class="value"><%= h.Lost %></span> lost
			</span>
			<span title="Copy status" class="copy_status">
				<span class="value"><%= h.Missing %></span> missing
			</span>
			<span title="Copy status" class="copy_status">
				<span class="value"><%= h.Cleaning %></span> cleaning
			</span>
			<span title="Copy status" class="copy_status">
				<span class="value"><%= h.Mending %></span> mending
			</span>
			<span title="Copy status" class="copy_status">
				<span class="value"><%= h.Reshelving %></span> reshelving
			</span>
			<span title="Copy status" class="copy_status">
				<span class="value"><%= in_process %></span> in process
			</span>
			<span title="Copy status" class="copy_status">
				<span class="value"><%= in_transit %></span> in transit
			</span>
			<span title="Copy status" class="copy_status">
				<span class="value"><%= on_holds_shelf %></span> on holds shelf
			</span>
			<span title="Copy status" class="copy_status">
				<span class="value"><%= on_order %></span> on order
			</span>
			<span title="Copy status" class="copy_status">
				<span class="value"><%= checked_out %></span> checked out
			</span>
		</li>
		'''
		show_holding = (holding_id, copy) ->
			@append(tpl_holding_details
				holding_id: holding_id
				h:              copy
				callnumber:     format_callnumber copy.callnumber
				checked_out:    copy['Checked out']
				in_process:     copy['In process']
				in_transit:     copy['In transit']
				on_holds_shelf: copy['On holds shelf']
				on_order:       copy['On order']
				# > FIXME:
				# *_.template()* is not able to handle property names with spaces.
				# and so we need to specify them explicitly.
			).find('.value').each ->
				$(@).parent().remove() unless $(@).text()
			@listview 'refresh'


		# Define a template and its accompanying function
		# to show due date for a checked out circ.
		tpl_due_date = _.template '''
			<span id="<%= barcode %>">Due date <%= duedate %></span>
		'''
		pad = (x) -> if x < 10 then '0' + x else x
		datestamp = (x) -> "#{pad x.getMonth() + 1}/#{pad x.getDate()}/#{x.getFullYear()}"
		show_due_date = (x) ->
			due_date = if x.circulations? then x.circulations[0].due_date else ''
			@append tpl_due_date {
				barcode: x.barcode
				duedate: datestamp due_date
			} if due_date
			return


		# We try to build the view of holdings of a possible hold target.
		# If a holding is checked out, we will try to get its due date.
		@html(holding_details)
		.trigger('create')
		.find('[data-role="listview"]')
		.openils "holding details ##{title_id}", 'search.biblio.copy_location_counts.summary.retrieve',
			id: title_id
			org_id: search_ou
			depth: search_depth
		, (copy_location) ->
			if copy_location instanceof Error then return @failed 'holding details' else @succeeded()

			# We don't show the holding list if there are no holdings as
			# indicated by an empty copy_location list.
			if copy_location.length is 0
				@parent().empty()
				return

			@publish 'opac.title_hold', [title_id]

			# Upon successfully receving a list of *copy* objects from the server
			# >FIXME: we should show available copies first.
			for copy in copy_location

				# We will only show this *copy*
				# if its depth is within scope of the search depth
				copy_depth = OU.id_depth copy.org_id
				continue unless search_depth <= copy_depth

				# * We need to remap some values of this *copy* to displayable names:
				#   * Map org id to org name
				#   * Map status number to status name
				copy.org_name = OU.id_name copy.org_id
				copy[status_names[id].name] = n for id, n of copy.available

				# * We calculate a unique identifier for this holding
				holding_id = ("#{copy.org_id} #{title_id} #{format_callnumber copy.callnumber}").replace /\s+|\.+/g, '_'

				# * We show this holding using details from this *copy*
				show_holding.call @, holding_id, copy

				# * If this *copy* is checked out, try to get its due date and show it
				if copy['Checked out']
					do (holding_id, copy) ->
						$holding = $("##{holding_id}").openils 'due dates', 'search.asset.copy.retrieve_by_cn_label',
							id:     title_id
							cn:     copy.callnumber
							org_id: copy.org_id
						, (ids) ->
							for copy_id in ids
								$holding.openils "due dates ##{copy_id}", 'search.asset.copy.fleshed2.retrieve', copy_id, show_due_date
		return @
