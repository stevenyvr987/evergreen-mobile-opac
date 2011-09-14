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
	$.fn.title_details = ($img) ->

		tpl_title_details = _.template '''
		<li>
			<div class="art_box"></div>
			<div class="info_box">
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
			</div>
		</li>
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

		hold = @closest('.plugin').data 'hold'

		@openils "title details ##{hold.target}", 'search.biblio.record.html', hold.target, (htmlmarc) ->
			@html(tpl_title_details {
				b: marc_text htmlmarc # Convert MARC HTML to MARC object.
				target_id: hold.target
				hold_id: hold.id or 0
			})
			.find('.value').each ->
				# Remove empty values.
				# FIXME: removal is not perfect, leaves empty divs behind.
				$(@).parent().empty() unless $(@).text()

			# Remove thumbnail container from list view is there is no thumbnail image
			if $img.get(0).naturalHeight > 0
				# FIXME: This is an attempt to double the size of the thumbnail,
				# but it is stymied by the fixed size of the outer conainer.
				#h = $img.get(0).naturalHeight
				#w = $img.get(0).naturalWidth
				#$img.height(2 * h).width(2 * w)
				$('.art_box', @).append $img.attr('title', '')
			else
				$('.art_box', @).remove()

			@listview 'refresh'
			return

		# Show a large version of the thumbnail image in a dialogue
		@delegate 'img`', 'click', (e) ->
			src = e.target.src.replace 'small', 'large'
			$.mobile.changePage $('#cover_art').find('.content').html("<img src=#{src}>").end()
			return false


	# Plugin to show holding details for a hold target.
	$.fn.holding_details = ->

		$plugin      = @closest '.plugin'
		hold         = $plugin.data 'hold'
		search_ou    = $plugin.data 'search_ou'
		search_depth = $plugin.data 'search_depth'
		ou_tree      = $plugin.data 'ou_tree'
		ou_types     = $plugin.data 'ou_types'
		status_names = $plugin.data 'status_names'

		# Show each item holding in a listview
		tpl_holding_details = _.template '''
		<li class="holding status_line" id="<%= holding_id %>">
			<div>
				<span><span title="Circulating branch or library" class="value"><%= h.org_name %></span></span>
				<span> / <span title="Name of collection" class="value"><%= h.copylocation %></span></span>
				<span> / <span title="Call number" class="value"><%= h.callnumber %></span></span>
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
			# FIXME: _.template is not able to handle property names with spaces.
			@append( tpl_holding_details {
				holding_id: holding_id
				h:              copy
				checked_out:    copy['Checked out']
				in_process:     copy['In process']
				in_transit:     copy['In transit']
				on_holds_shelf: copy['On holds shelf']
				on_order:       copy['On order']
			}).find('.value').each ->
				# Remove empty values of Holdings Details section.
				$(@).parent().remove() unless $(@).text()

			# We need to refresh the jQM listview with new list item.
			@listview 'refresh'

		# The following element is appended to each div.holding, one elem for each checked out circ.
		tpl_due_date = _.template '''
			<span id="<%= barcode %>">Due date <%= duedate %></span>
		'''
		pad = (x) -> if x < 10 then '0' + x else x
		datestamp = (x) ->
			"#{pad x.getMonth() + 1}/#{pad x.getDate()}/#{x.getFullYear()}"
		show_due_date = (x) ->
			due_date = if x.circulations? then x.circulations[0].due_date else ''
			@append tpl_due_date {
				barcode: x.barcode
				duedate: datestamp due_date
			} if due_date
			return

		# Build the view of holdings asynchronously.
		# If a holding is checked out, schedule a second ajax call to get its due date.
		@empty().loading "holding details ##{hold.target}"
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
				holding_id = ("#{copy.org_id} #{hold.target} #{copy.callnumber}").replace /\s+|\.+/g, '_'
				show_holding.call @, holding_id, copy

				# For checked out copies, fill in data from circs asynchronously.
				if copy['Checked out']
					do (holding_id, copy) ->
						$holding = $("##{holding_id}").openils 'due dates', 'search.asset.copy.retrieve_by_cn_label',
							id:     hold.target
							cn:     copy.callnumber
							org_id: copy.org_id
						, (ids) ->
							for copy_id in ids
								$holding.openils "due dates ##{copy_id}", 'search.asset.copy.fleshed2.retrieve', copy_id, show_due_date
		return @



	# Plugin to show the place hold form.
	# Default pickup location is specified by hold request.
	# Otherwise, set it to ou id of last copy listed.
	# FIXME: would be good to mark these circ_ou's in the ou selection list.
	$.fn.hold_details = ->

		hold = @parent().closest('.plugin').data('hold')

		# The content for the plugin is a form to enable the user
		# to place a title-level hold on the current item.
		$form = $ '''
		<form class="place_hold" data-ajax="false">
			<div data-role="fieldcontain">
				<label for="edit_hold_org_unit">Hold a copy of this title at</label>
				<span id="edit_hold_org_unit" class="org_unit_selector"></span>
			</div>
			<fieldset class="ui-grid-a">
				<!--div class="ui-block-a"><button type="reset">Cancel</button></div-->
				<div class="ui-block-a"><a href="#" data-role="button" data-rel="back" class="reset">Cancel</a></div>
				<!--div class="ui-block-b"><button type="submit">Place Hold</button></div-->
				<div class="ui-block-b"><a href="#" data-role="button" data-rel="back" class="submit">Place Hold</a></div>
			</fieldset>
		</form>
		'''

		hide_form = ->
			#@closest('.ui-dialog').dialog 'close'
			return false

		place_hold = ->

			# Prepare the hold request based on
			# data read from the hold screen
			# and data read from the place hold form.
			o = {}
			for x in $('form.place_hold', @).serializeArray()
				o[x.name] = x.value
			$.extend hold, o

			# Calculate the selection depth for hold targeting
			if window.query?.ol?
				$plugin = @closest '.plugin'
				ou_tree = $plugin.data 'ou_tree'
				ou_types = $plugin.data 'ou_types'
				ol = window.query.ol.toUpperCase()
				for id, ou of ou_tree when ou.shortname is ol
					hold.selection_depth = ou_types[ou.ou_type].depth
					break

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

			else
				eg.openils 'circ.title_hold.is_possible', hold, (possible) =>
					if possible?.success
						eg.openils 'circ.holds.create', hold, (result) =>
							if ok = typeof result isnt 'object'
								# Publish notice of successful hold creation to user
								@publish 'notice', ['Hold created']
								# and to other plugins.
								@publish 'holds_summary', [hold]
							else
								@publish 'prompt', ['Hold request failed', "#{result[0].desc}"]
					else
						if possible?.last_event?.desc
							@publish 'prompt', ['Hold request failed', "#{possible.last_event.desc}"]
						else
							@publish 'prompt', [
								'This title is not eligible for a hold.'
								'Please ask your friendly library staff for assistance.'
							]

			return false

		# Append the place hold form as its main content
		@html($form)
		# Convert the form into a jQM page
		.find('form').page()

		# Build an ou selector to show pickup libraries.
		$('.org_unit_selector', @).ou_tree(
			'name': 'pickup_lib'
			'all': false
			'selected': Number hold.pickup_lib #or Number copy.org_id
			'indent': '. '
			'focus': true
		)

		# Clicking submit button places a hold.
		$('a.submit', @).bind 'click', => place_hold.call @

		# Keyboard shortcuts:
		# FIXME: not working for jQM
		#
		# Pressing esc key has same effect as clicking reset button.
		@delegate 'form.place_hold', 'keyup', (e) =>
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


	# Plugin to show the edit hold dialog,
	# which includes title details, hold details, and holdings details.
	$.fn.edit_hold = ->

		count = 0
		total = 0

		# Define the header for navigating to prev/next title
		nav_bar = _.template '''
		<h3>
			Title <span class="count"><%= count %></span> of <span class="total"><%= total %></span>
		</h3>
		<div class="ui-btn-right">
			<div data-role="button" data-icon="arrow-u" class="prev">Previous</div>
			<div data-role="button" data-icon="arrow-d" class="next">Next</div>
		</div>
		'''
		# Build the nav bar with inital count and total
		$('.nav_bar', @).html(nav_bar count: 0, total: 0)

		# Upon user clicking a button in the nav bar
		.delegate 'div', 'click', (e) =>
			title_id = @closest('.plugin').data('hold').titleid
			$target = $(e.currentTarget)

			count = Number $('.count', @).text()

			if $target.hasClass 'prev'
				unless count is 1
					count -= 1
					$('.count', @).text count
				@publish 'title', [title_id, -1]
			else if $target.hasClass 'next'
				unless count is total
					count += 1
					$('.count', @).text count
				@publish 'title', [title_id, +1]
			return false

		# Build the content structure of the details view
		# FIXME: add option for user to see all tags of MARC record.
		# FIXME: add class name 'marctag'.
		content = '''
		<ul class="title_details" data-role="listview" data-inset="true"></ul>
		<h3>Copies available for this title</h3>
		<ul class="holding_details" data-role="listview" data-inset="true"></ul>
		<div class="hold_details"></div>
		'''
		$('.content', @).html(content)

		# Define a utility function to show content of the details view.
		show_content = (hold, search_ou, search_depth, $img) ->

			# Cache arguments as data objects.
			@data('hold', hold)
			.data('search_ou', search_ou)
			.data('search_depth', search_depth)

			# Get more cacheable data objects (asynchronously and in parallel).
			# In the future, we could get these objects once per browser session.
			parallel(
				ouTypes:         eg.openils 'actor.org_types.retrieve'
				ouTree:          eg.openils 'actor.org_tree.retrieve'
				copy_status_map: eg.openils 'search.config.copy_status.retrieve.all'
			).next (x) =>
				@data('ou_tree', x.ouTree)
				.data('ou_types', x.ouTypes)
				.data('status_names', x.copy_status_map)

				# Show the three main areas of the details view
				$('.title_details', @).title_details $img
				$('.holding_details', @).holding_details()
				$('.hold_details', @).hold_details()

		# Prepare this container as a plugin.
		@plugin('edit_hold')

		# Upon receiving a potential request on the hold create data channel,
		.subscribe 'hold_create', (title_id, search_ou, search_depth, $img, titles_total, titles_count) =>

			# Build a hold request object
			hold =
				target: title_id # version 1.6 software
				titleid: title_id # version 2.0 software
				hold_type: 'T' # default type
				selection_depth: 0
				# Set default pickup_lib to user's home ou if defined
				# (implies user has logged in)
				pickup_lib: Number eg.auth.session.user.home_ou

			# Build DOM content based on hold request
			show_content.call @, hold, search_ou, search_depth, $img

			# Update total and count numbers in header
			$('.total', @).text total = titles_total
			$('.count', @).text count = titles_count

			# Change to this page unless it is already active
			$.mobile.changePage @page() unless @ is $.mobile.activePage

		# Currently, the interface doesn't have controls to update holds.
		.subscribe 'hold_update', (hold) =>
			show_content.call @, hold
