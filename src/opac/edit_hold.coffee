# We define a module to contain the *edit_hold* jQuery plugin and its dependent
# plugins.  The master plugin and its dependencies will show three areas of
# content.
#
# 1. Details of the title
# 2. Copies of the title
# 3. An interactive form for the user to place a hold on the title
#
# Possible extensions to the plugin are as follows.
#
# * Place other types of holds, eg, on the title's copies or volumes
# * Edit an already placed hold

module 'opac.edit_hold', imports(
	'eg.eg_api'
	'template'
	'plugin'
	'opac.ou_tree'
), (eg, _) ->

	# ***
	# Define a jQuery plugin to show title details of a possible hold target.
	# The hold object will have been stored in the plugin's data *hold* object.
	# The plugin will show a large version of a given thumbnail image if the user clicks the thumbnail.
	$.fn.title_details = ($img) ->

		# We will format title details as a jQuery Mobile list view of one list element.
		tpl_content = _.template '''
		<li class="title_details" id="target_id_<%= target_id %>">
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

		# Define a one-liner to 'pinch' white space out of a jQuery object,
		# ie, remove white space duplicates from inside
		# and trim white space before and after.
		pinch = ($x) -> $.trim $x.text().replace /\s+/g, ' '


		# Define a function to mutate a given MARC text in HTML format to a MARC data object.
		# MARC tags are mapped to text fields according to the *tags2text* object.
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

		marc_text = (html) ->
			marctext = []
			$('.marc_tag_row', html).each ->
				marctext.push pinch($ @).replace(/^(.....)\. /, '$1').replace(/^(...) \. /, '$1')

			# For each specification...
			for name, tags of tags2text
				text = ''
				# For each specified MARC tag...
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
				# We will delete this entry if it has no MARC text.
				if text.length then tags2text[name] = text else delete tags2text[name]
			return tags2text

		# We get the hold request object,
		# which has been stored in the plugin's data *hold* object.
		hold = @closest('.plugin').data 'hold'

		# We try to get the MARC HTML record of the hold target.
		@openils "title details ##{hold.target}", 'search.biblio.record.html', hold.target, (htmlmarc) ->

			# Upon success, we will fill in the content template with data from the MARC object,
			# and remove the empty parts of the template.
			@html(tpl_content
				b: marc_text htmlmarc
				target_id: hold.target
				hold_id: hold.id or 0
			).find('.value').each ->
				$(@).parent().empty() unless $(@).text()
				# > FIXME: empty divs may be left behind

			@listview 'refresh'
			return

		# We add the given thumbnail image.
		if $img.get(0).naturalHeight > 0
			$('.title_details', @).prepend $img.prop('title', '')

		# Upon the user clicking the thumbnail image,
		# we will show the large image in a jQuery Mobile dialogue.
		@delegate 'img`', 'click', (e) ->
			src = e.target.src.replace 'small', 'large'
			$.mobile.changePage $('#cover_art').find('.content').html("<img src=#{src}>").end()
			return false


	# ***
	# Define a jQuery plugin to show the holding details of a possible hold target.
	# The plugin will not react to any user events.
	$.fn.holding_details = ->

		$plugin      = @closest '.plugin'
		hold         = $plugin.data 'hold'
		search_ou    = $plugin.data 'search_ou'
		search_depth = $plugin.data 'search_depth'
		ou_tree      = $plugin.data 'ou_tree'
		ou_types     = $plugin.data 'ou_types'
		status_names = $plugin.data 'status_names'

		# Define a template and its accompanying function
		# to show details of a holding in a jQuery Mobile listview.
		# and to remove the empty parts of the template.
		# Details are specified by the given *holding_id* and *copy* object.
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
			@append(tpl_holding_details
				holding_id: holding_id
				h:              copy
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
		@empty().loading "holding details ##{hold.target}"
		eg.openils 'search.biblio.copy_location_counts.summary.retrieve',
			id: hold.target
			org_id: search_ou
			depth: search_depth
		, (copy_location) =>
			if copy_location instanceof Error then return @failed 'holding details' else @succeeded()

			# Upon successfully receving a list of *copy* objects from the server
			# >FIXME: we should show available copies first.
			for copy in copy_location

				# We will only show this *copy*
				# if its depth is within scope of the search depth
				copy_depth = ou_types[ou_tree[copy.org_id].ou_type].depth
				continue unless search_depth <= copy_depth

				# * We need to remap some values of this *copy* to displayable names:
				#   * Map org id to org name
				#   * Map status number to status name
				copy.org_name = ou_tree[copy.org_id].name
				copy[status_names[id].name] = n for id, n of copy.available

				# * We calculate a unique identifier for this holding
				holding_id = ("#{copy.org_id} #{hold.target} #{copy.callnumber}").replace /\s+|\.+/g, '_'

				# * We show this holding using details from this *copy*
				show_holding.call @, holding_id, copy

				# * If this *copy* is checked out, try to get its due date and show it
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


	# ***
	# Define the jQuery plugin to show a form
	# to allow the user to place a title-level hold.
	# Default pickup location is specified by hold request.
	# Otherwise, set it to ou id of last copy listed.
	# >FIXME: would be good to mark these circ_ou's in the ou selection list.
	$.fn.hold_details = ->

		# We get the possible hold target from the parent plugin's *hold* data object.
		hold = @parent().closest('.plugin').data('hold')

		# The content for the plugin is a form to enable the user
		# to place a title-level hold on the current item.
		# The main input element is a selector to allow the user to select the pickup library.
		$form = $ '''
		<form class="place_hold" data-ajax="false">
			<div data-role="fieldcontain">
				<label for="edit_hold_org_unit">Hold a copy of this title at</label>
				<span id="edit_hold_org_unit" class="org_unit_selector"></span>
			</div>
			<fieldset class="ui-grid-a">
				<div class="ui-block-a"><a href="#" data-role="button" data-rel="back" class="reset">Cancel</a></div>
				<div class="ui-block-b"><a href="#" data-role="button" data-rel="back" class="submit">Place Hold</a></div>
			</fieldset>
		</form>
		'''

		hide_form = ->
			#@closest('.ui-dialog').dialog 'close'
			return false

		# Define a function to handle the submit event.
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
			# >FIXME: need better success message.
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

		# We create the place hold form for the plugin.
		@html($form).trigger 'create'

		# We build a selector for the form to show a list of pickup libraries.
		$('.org_unit_selector', @).ou_tree(
			'name': 'pickup_lib'
			'all': false
			'selected': Number hold.pickup_lib
			'indent': '. '
			'focus': true
		)

		# Upon the user clicking the submit button, we will place a hold.
		$('a.submit', @).bind 'click', => place_hold.call @

		# >FIXME: esc key does not work for jQM
		@delegate 'form.place_hold', 'keyup', (e) =>
			switch e.keyCode
				when 27 then hide_form.call @
			return false

		# We define some keyboard shortcuts:
		@delegate 'button', 'keyup', (e) =>
			switch e.keyCode
				# * Upon the user pressing the esc key,
				# we will ensure it has same the effect as clicking the reset button.
				when 27 then hide_form.call @
			switch e.keyCode
				# * Upon the user pressing the enter key,
				# we will ensure it has an effect if the user is focussed on the submit or reset button.
				when 13
					$target = $(e.target)
					switch $target
						when $target.is '[type=reset]' then hide_form.call @
						when $target.is '[type=submit]' then place_hold.call @
			return false


	# ***
	# We define the master jQuery plugin to show the edit hold dialog,
	# which includes title details, holdings details, and hold details.
	# The plugin will refresh its content
	#
	# * If a potential request is received on *hold_create* channel
	# * If the user presses next or previous links on the nav bar
	#
	$.fn.edit_hold = ->

		# One of the responsibility of the master plugin
		# is to define a navigation bar to allow the user
		# to incrementally scroll through the search result list.
		# The nav bar will also show the current number of the title displayed
		# and the total nunmber of titles in the result list.
		nav_bar = _.template '''
		<h3>
			Title <span class="count"><%= count %></span> of <span class="total"><%= total %></span>
		</h3>
		<div class="ui-btn-right">
			<div data-role="button" data-icon="arrow-u" class="prev"></div>
			<div data-role="button" data-icon="arrow-d" class="next"></div>
		</div>
		'''

		# We build the nav bar with count and total initialized to zero.
		count = 0
		total = 0

		$('.nav_bar', @).html(nav_bar count: 0, total: 0)

		# Upon the user clicking the prev or next button in the nav bar,
		# we will publish the current *title_id* and a step indicator (+1 or -1) on *title* channel.
		# We will also ensure that the count is properly adjusted
		# and that it will stop adjusting if it reaches the bottom or top boundary.
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


		# Define the container for the three main areas of content.
		# >FIXME:
		#
		# * Add option for user to see all tags of MARC record
		# * Add class name 'marctag'
		content = '''
		<ul class="title_details" data-role="listview" data-inset="true"></ul>
		<h3>Copies available for this title</h3>
		<ul class="holding_details" data-role="listview" data-inset="true"></ul>
		<div class="hold_details"></div>
		'''
		$('.content', @).html(content)

		# Define a function to show content.
		show_content = (hold, search_ou, search_depth, $img) ->

			# We cache function arguments as data objects attached to the plugin
			# so that child plugins can access them.
			@data('hold', hold)
			.data('search_ou', search_ou)
			.data('search_depth', search_depth)

			# We try to get more cacheable data objects (asynchronously and in parallel)
			# that will be needed by child plugins.
			parallel(
				ouTypes:         eg.openils 'actor.org_types.retrieve'
				ouTree:          eg.openils 'actor.org_tree.retrieve'
				copy_status_map: eg.openils 'search.config.copy_status.retrieve.all'
			).next (x) =>
				@data('ou_tree', x.ouTree)
				.data('ou_types', x.ouTypes)
				.data('status_names', x.copy_status_map)

				# Upon success, we will show the content by applying the three child plugins.
				$('.title_details', @).title_details $img
				$('.holding_details', @).holding_details()
				$('.hold_details', @).hold_details()
			# >FIXME:
			#
			# * We should get these objects once per browser session.
			# * We should also rethink the notion of using data objects as a caching mechanism.

		# We prepare this container as a plugin.
		@plugin('edit_hold')

		# Upon receiving a potential request on *hold_create* channel
		.subscribe 'hold_create', (title_id, search_ou, search_depth, $img, titles_total, titles_count) =>

			# We will build a title-level hold request
			# and set the default pickup library
			# to the user's home ou if it is defined
			# (implies user has logged in).
			hold =
				target: title_id # version 1.6 software
				titleid: title_id # version 2.0 software
				hold_type: 'T' # default type is 'title-level'
				selection_depth: 0
				pickup_lib: Number eg.auth.session.user.home_ou

			# We will show content based on the hold request.
			show_content.call @, hold, search_ou, search_depth, $img

			# We will update total and count numbers in the nav bar.
			$('.total', @).text total = titles_total
			$('.count', @).text count = titles_count

			# We will change to this page unless it is already active.
			$.mobile.changePage @page() unless @ is $.mobile.activePage

		# Upon receiving a potential request on *hold_update* channel,
		# we will show its content, but currently the plugin doesn't have controls to update holds.
		.subscribe 'hold_update', (hold) =>
			show_content.call @, hold
