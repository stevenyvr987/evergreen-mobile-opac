#  edit_hold.js
# 
#  Place or edit a hold. Subscribes to 'hold_create' and 'hold_update', which
#  perform predictable actions. 'hold_create' takes an item id, and
#  'hold_update' takes a hold object from the server.
# 
#   @publish('hold_create', [item_id])
#   @publish('hold_update', [hold_obj])
# 
#  The plugin hides the main pane (more accurately, asks the system to), and
#  shows it again once the user finishes their actions.

module 'opac.edit_hold', imports(
	'eg.fieldmapper'
	'eg.eg_api'
	'template'
	'plugin'
	'opac.ou_tree'
), (fm, eg, _) ->


	# Plugin to show title details for a hold target.
	$.fn.title_details = ->

		tpl_title_details = _.template '''
			<div>Title:                <span class="value"><%= b.title            %></span></div>
			<div>Author:               <span class="value"><%= b.author           %></span></div>
			<div>Publisher:            <span class="value"><%= b.publisher        %></span></div>
			<div>Call Number:          <span class="value"><%= b.callnumber       %></span></div>
			<div>ISBN:                 <span class="value"><%= b.isbn             %></span></div>
			<div>ISSN:                 <span class="value"><%= b.issn             %></span></div>
			<div>UPC:                  <span class="value"><%= b.upc              %></span></div>
			<div>Publisher Number:     <span class="value"><%= b.publisher_number %></span></div>
			<div>Physical Description: <span class="value"><%= b.phy_descr        %></span></div>
			<div>Edition:              <span class="value"><%= b.edition          %></span></div>
			<div>Frequency:            <span class="value"><%= b.frequency        %></span></div>
		'''
		tags2text =
			title:            { '245':'abchp' }
			author:           { '100':'', '110':'', '111':'', '130':'', '700':'', '710':'', '711':'' }
			publisher:        { '260':'' }
			callnumber:       { '092':'', '099':'' }
			isbn:             { '020':'' }
			issn:             { '022':'' }
			upc:              { '024':'' }
			publisher_number: { '028':'' }
			phy_descr:        { '300':'' }
			edition:          { '250':'' }
			frequency:        { '310':'' }

		# 'Pinch' the text out of a jQuery object,
		# ie, remove white space duplicates from inside
		# and trim white space before and after.
		pinch = ($x) -> $.trim $x.text().replace /\s+/g, ' '

		# Convert a MARC HTML text string into a MARC data object according to this specification object.
		# The spec. object is mutated to contain the MARC text.
		marc_text = (html) ->

			marctext = []
			$('.marc_tag_row', html).each ->
				marctext.push pinch($ @).replace(/^(.....)\. /, '$1').replace(/^(...) \. /, '$1')

			# For each specification...
			for name, tags of tags2text
				text = ''
				# For each MARC tag specified...
				for tag, subfields of tags
					# For each text line in MARC record...
					for x in marctext
						continue unless x.match new RegExp "^#{tag}"
						codes = subfields.split ''
						# For each subfield code specified, or for all codes...
						for code in (if codes.length then codes else ['.'])
							code = "\\u2021#{code}(.+?)(?= \\u2021|$)"
							continue unless x2 = x.match new RegExp code, 'g'
							more = (y.replace /^../, '' for y in x2).join ' '
							text = unless text then more else "#{text} #{more}"
					break if text.length
				# Delete specification entry if it has no MARC text.
				#if text.length then @[name] = text else delete @[name]
				if text.length then tags2text[name] = text else delete tags2text[name]
			return tags2text

		hold = @parent().data 'hold'

		@openils 'title details', 'search.biblio.record.html', hold.target, (htmlmarc) ->
			@html(tpl_title_details {
				b: marc_text htmlmarc # Convert MARC HTML to MARC object.
				target_id: hold.target
				hold_id: hold.id or 0
			}).find('.value').each ->
				# Remove empty values.
				# FIXME: removal is not perfect, leaves empty divs behind.
				$(@).parent().empty() unless $(@).text()


	# Plugin to show holding details for a hold target.
	$.fn.holding_details = ->

		$parent      = @parent()
		hold         = $parent.data 'hold'
		search_ou    = $parent.data 'search_ou'
		search_depth = $parent.data 'search_depth'
		ou_tree      = $parent.data 'ou_tree'
		ou_types     = $parent.data 'ou_types'
		status_names = $parent.data 'status_names'

		# The following element is appended to div.holding_details, one for each holding.
		tpl_holding_details = _.template '''
		<div class="holding" id="<%= holding_id %>">
			<span>   <span title="Circulating branch or library" class="value"><%= h.org_name %></span></span>
			<span> / <span title="Name of collection" class="value"><%= h.copylocation %></span></span>
			<span> / <span title="Call number" class="value"><%= h.callnumber %></span></span>

			<span title="Copy status" class="copy_status">
				/ <span class="value"><%= h.Available %></span> available</span>
			<span title="Copy status" class="copy_status">
				/ <span class="value"><%= h.Lost %></span> lost</span>
			<span title="Copy status" class="copy_status">
				/ <span class="value"><%= h.Missing %></span> missing</span>
			<span title="Copy status" class="copy_status">
				/ <span class="value"><%= h.Cleaning %></span> cleaning</span>
			<span title="Copy status" class="copy_status">
				/ <span class="value"><%= h.Mending %></span> mending</span>
			<span title="Copy status" class="copy_status">
				/ <span class="value"><%= h.Reshelving %></span> reshelving</span>
			<span title="Copy status" class="copy_status">
				/ <span class="value"><%= in_process %></span> in process</span>
			<span title="Copy status" class="copy_status">
				/ <span class="value"><%= in_transit %></span> in transit</span>
			<span title="Copy status" class="copy_status">
				/ <span class="value"><%= on_holds_shelf %></span> on holds shelf</span>
			<span title="Copy status" class="copy_status">
				/ <span class="value"><%= on_order %></span> on order</span>
			<span title="Copy status" class="copy_status">
				/ <span class="value"><%= checked_out %></span> checked out</span>
		</div>
		'''
		show_holding = (holding_id, copy) ->
			# FIXME: _.template is not able to handle property names with spaces.
			@append(tpl_holding_details {
				holding_id: holding_id
				h:              copy
				checked_out:    copy['Checked out']
				in_process:     copy['In process']
				in_transit:     copy['In transit']
				on_holds_shelf: copy['On holds shelf']
				on_order:       copy['On order']
			}).find('.value').each ->
				# Remove empty values of Holdings Details section.
				$(@).parent().empty() unless $(@).text()

		# The following element is appended to each div.holding, one elem for each checked out circ.
		tpl_due_date = _.template '''
			<span id="<%= barcode %>"> / Due date <%= duedate %></span>
		'''
		pad = (x) -> if x < 10 then '0' + x else x
		datestamp = (x) ->
			"#{pad x.getMonth() + 1}/#{pad x.getDate()}/#{x.getFullYear()}"
		show_due_date = (x) ->
			@append tpl_due_date {
				barcode: x.barcode
				#duedate: x.circulations?[0].due_date.slice 0, 10
				duedate: datestamp x.circulations[0].due_date
			} if x.circulations?

		@loading 'holding details'
		eg.openils 'search.biblio.copy_location_counts.summary.retrieve',
			id: hold.target
			org_id: search_ou
			depth: search_depth
		, (copy_location) =>
			if copy_location instanceof Error then return @failed 'holding details' else @succeeded()

			# FIXME: show available copies first.
			for copy in copy_location

				# Filter by search request's org_unit's depth.
				copy_depth = ou_types[ou_tree[copy.org_id].ou_type].depth
				continue unless search_depth <= copy_depth

				# Convert org id to org name.
				copy.org_name = ou_tree[copy.org_id].name
				# Convert status number to status name.
				for id, n of copy.available
					copy[status_names[id].name] = n

				# Calculate a unique identifier for a title's holdings for an ou.
				holding_id = ("#{copy.org_id} #{hold.target} #{copy.callnumber}").replace /\s+/g, '_'
				show_holding.call @, holding_id, copy

				# For checked out copies, fill in data from circs asynchronously.
				( (holding_id, copy) ->
					$holding = $("##{holding_id}").openils 'due dates', 'search.asset.copy.retrieve_by_cn_label',
						id:     hold.target
						cn:     copy.callnumber
						org_id: copy.org_id
					, (ids) ->
						for copy_id in ids
							$holding.openils 'due dates', 'search.asset.copy.fleshed2.retrieve', copy_id, show_due_date
				)(holding_id, copy) if copy['Checked out']
		return @



	# Plugin to show the place hold form.
	# Default pickup location is specified by hold request.
	# Otherwise, set it to ou id of last copy listed.
	# FIXME: would be good to mark these circ_ou's in the ou selection list.
	$.fn.hold_details = ->

		hold = @parent().data 'hold'

		tpl_place_hold = '''
		<form class="place_hold">
			<div>
				<label>Hold a copy of this title at</label>
				<span class="org_unit_selector" />
			</div> <div>
				<button type="submit">Place Hold</button>
				<button type="reset">Cancel</button>
			</div>
		</form>
		'''

		hide_form = ->
			$.unblockUI { onUnblock: => @empty() }
			return false

		place_hold = ->

			# Prepare the hold request based on
			# data read from the hold screen
			#ou_tree = @parent().data 'ou_tree'
			#ou_types = @parent().data 'ou_types'
			# and data read from the place hold form.
			o = {}
			for x in $('form.place_hold', @).serializeArray()
				o[x.name] = x.value
			$.extend hold, o
			#$.extend hold, o, { selection_depth: ou_types[ ou_tree[Number o.pickup_lib].ou_type ].depth }

			# Request to update or create a hold.
			# FIXME: need better success message.
			$plugin = @
			if hold.id
				eg.openils 'circ.hold.update', hold, (result) =>
					if ok = typeof result isnt 'object'
						# Publish notice of successful hold update to user
						@publish 'notice', ['Hold updated']
						# and to other plugins.
						@publish 'holds_summary', [hold.id]
					else
						@publish 'prompt', ['Hold update failed', "#{result[0].desc}"]
					hide_form.call @

			else
				eg.openils 'circ.title_hold.is_possible', hold, (possible) =>
					if possible?.success
						eg.openils 'circ.holds.create', hold, (result) =>
							if ok = typeof result isnt 'object'
								hide_form.call @
								# Publish notice of successful hold creation to user
								@publish 'notice', ['Hold created']
								# and to other plugins.
								@publish 'holds_summary', [hold]
							else
								hide_form.call @
								@publish 'prompt', ['Hold request failed', "#{result[0].desc}"]
					else
						hide_form.call @
						@publish 'prompt', [
							'This title is not eligible for a hold.'
							'Please ask your friendly library staff for assistance.'
						]

			return false

		@append(tpl_place_hold)

		# Clicking submit button places a hold.
		.delegate('[type=submit]', 'click', => place_hold.call @)

		# Clicking reset button hides the form.
		.delegate('[type=reset]', 'click', => hide_form.call @)

		# Keyboard shortcuts:
		#
		# Pressing esc key has same effect as clicking reset button.
		.delegate 'form.place_hold', 'keyup', (e) =>
			switch e.keyCode
				when 27 then hide_form.call @
			return false

		# Pressing enter key will have an effect if focussed on submit or reset button.
		.delegate 'button', 'keyup', (e) =>
			switch e.keyCode
				when 27 then hide_form.call @
			switch e.keyCode
				when 13
					$target = $(e.target)
					switch $target
						when $target.is '[type=reset]' then hide_form.call @
						when $target.is '[type=submit]' then place_hold.call @
			return false

		# Build an ou selector to show pickup libraries.
		$('.org_unit_selector', @).ou_tree(
			'name': 'pickup_lib'
			'all': false
			'selected': Number hold.pickup_lib #or Number copy.org_id
			'indent': '. '
			'focus': true
		)
		return @


	$.fn.edit_hold = ->
		# FIXME: add option for user to see all tags of MARC record.
		# FIXME: add class name 'marctag'.
		tpl_details = '''
		<div class="title_details" />
		<hr />
		<div class="hold_details" />
		<hr />
		<div>Copies available for this title</div>
		<div class="holding_details" />
		'''

		show_form = (hold, search_ou, search_depth) ->

			# Persist the hold data object.
			# Build details pane.
			@data('hold', hold).html tpl_details

			# Get cacheable data objects (in parallel and asynchronously).
			# In the future, we could get these objects once per browser session.
			parallel(
				ouTypes:         eg.openils 'actor.org_types.retrieve'
				ouTree:          eg.openils 'actor.org_tree.retrieve'
				copy_status_map: eg.openils 'search.config.copy_status.retrieve.all'
			).next (x) =>

				# Show details pane.
				$.blockUI { message: @ }

				@
				.data('hold', hold)
				.data('search_ou', search_ou)
				.data('search_depth', search_depth)
				.data('ou_tree', x.ouTree)
				.data('ou_types', x.ouTypes)
				.data('status_names', x.copy_status_map)

				$('.title_details', @).title_details()
				$('.holding_details', @).holding_details()
				$('.hold_details', @).hold_details()
				return

			return false


		return @empty().hide() if @plugin()

		@plugin('edit_hold').empty().hide()

		# Set default pickup_lib to user's home ou if defined (implies user has logged in)
		.subscribe 'hold_create', (id, search_ou, search_depth) =>
			hold =
				target: id # version 1.6 software
				titleid: id # version 2.0 software
				hold_type: 'T' # default type
				selection_depth: 0
				pickup_lib: Number eg.auth.session.user.home_ou
			show_form.call @, hold, search_ou, search_depth
			return false

		.subscribe 'hold_update', (hold) =>
			show_form.call @, hold
			return false
