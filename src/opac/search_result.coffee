# We define a custom jQuery plugin that will behave as follows.
#
# * Try searching the public catalogue upon receiving a *search* object
# * Publish title summaries on *search_results* and show them to the user
# * Empty the result list upon receiving *clear_data*
# * Respond to three user actions in the list of title summaries
#
#   1. Show a jacket cover upon the user clicking a thumbnail image
#   2. Initiate an author search upon the user clicking an author link
#   3. Publish an object on *hold_create* upon the user clicking a title summary area
#
# * As a scrolling analogue, response 3 will also occur
# upon the plugin receiving an ID value and a plus or minus step indicator on *title*

define [
	'jquery'
	'eg/eg_api'
	'template'
	'settings'
	'plugin'
	'opac/cover_art'
	'opac/page_bar'
], ($, eg, _, rc) ->

	# ***
	# Define the plugin content, a list view of title summaries.
	# At the top and bottom of the list will be a *page_bar* the user can use to paginate.
	content = '''
	<div class="page_bar"></div>
	<ul data-role="listview" data-inset="true" data-split-icon="gear" class="result_list"></ul>
	<div class="page_bar"></div>
	'''

	# Define the template for a title summary.  The first anchor defines the
	# summary content, consisting of a thumbnail of the jacket cover, a line of
	# title information, and a line of holding and circulation status.  Note
	# that the img element for the thumbnail will be added dynamically and is
	# not part of the template.  The second anchor provides a way for the user
	# to try searching for the author.
	tpl_summary_info = _.template '''
	<li id="title_id_<%= title_id %>">
		<a href="#" class="title">
			<div class="info_box">
				<h3 class="info_line">
					<span class="title"></span>
					<div class="author"></div>
				</h3>
				<p>
					<span title="Publication date" class="pub_date"></span>
					<span title="Physical description" class="physical"></span>
					<span title="Format" class="resource_types"></span>
				</p>
				<p title="Location and call number of this title" class="callnumber"></p>
				<p class="copy_counts ui-li-count"><span class="counts_avail"></span> of <span class="counts_total"></span> available</p>
			</div>
		</a>
		<a class="author">Search other titles by this author</a>
	</li>
	'''

	# Define the template of a message that will show instead of an empty list
	tpl_zero_hits = _.template '''
	<div class="zero_hits">
		<strong>Sorry, no entries were found for "<%= query %>"</strong>
	</div>
	'''

	# ***
	# Define a function to show the info line
	show_summary_info = (mvr) ->
		$('span.title', @).text(mvr.title).prop 'title', mvr.title if mvr.title
		$('div.author', @).text(mvr.author).prop 'title', mvr.author if mvr.author
		$('.pub_date', @).text mvr.pubdate if mvr.pubdate
		$('.physical', @).text mvr.physical_description if mvr.physical_description
		$('.resource_types', @).text mvr.types_of_resource.join ', ' if mvr.types_of_resource.length

		# The ISBN string will be used as a key to getting the thumbnail image.
		# But the ISBN may be empty, or it may contain annotations or multiple
		# values.  As a coping strategy, we will pick the first ISBN value, if
		# there is one.  We will use it to get the corresponding thumbnail and
		# create an image element out of it.  We will create the img element
		# only if it is possibly needed.
		$('a.title', @).thumbnail_art(isbn[0]) if isbn = mvr.isbn?.match /^(\d+)\D/
		return

	# ***
	# Define a function to show the status line.
	show_copy_counts = (nc, depth) ->
		counts = (v for n, v of nc when Number(v.depth) is depth)[0]
		$('.counts_avail', @).text counts.available
		$('.counts_total', @).text counts.count


	# ***
	# Define a function to show the call number of a title.
	# We will format a call number as 'ou name / copy location / callnumber'.
	# There are some provisos to the format, as follows.
	show_callnumber = (cns, ou) ->
		$cn = $('.callnumber', @)
		if (cns).length
			first = cns[0]

			# * If all callnumbers do not match the first callnumber,
			# we will not show a callnumber.
			for cn in cns when cn.callnumber isnt first.callnumber
				return $cn.text 'Multiple locations and call numbers'

			# * If all ou names do not match the first ou name,
			# we will not show an ou name.
			ou_name = ou[first.org_id].name
			for cn in cns when ou[cn.org_id].name isnt ou_name
				return $cn.text "#{first.copylocation} / #{first.callnumber}"
				# >FIXME: Unfortunately,
				# if the request ou ID corresponds to a leaf of the ou tree,
				# we will not show an ou name.

			# * If all copy locations do not match the first copy location,
			# we will not show a copy location.
			for cn in cns when cn.copylocation isnt first.copylocation
				return $cn.text "#{first.callnumber}"
			$cn.text "#{ou_name} / #{first.copylocation} / #{first.callnumber}"


	# ***
	# Define a function to find the title ID of a given jQuery object or its closest ancestor.
	get_id = ($el) ->
		while $el.length > 0
			for c in ($el.prop('id') or '').split(' ')
				m = c.match /^title_id_(\d+)/
				return Number m[1] if m
			$el = $el.parent()
		return


	$.fn.search_result = ->

		current_location = ''
		current_name = ''
		current_depth = ''
		current_type = ''

		maxTab = 0

		@plugin('search_settings')
		.data 'settings',
			default_class: 'keyword'
			term: ''
			item_type: ''
			limit: 10
			visibility_limit: 1000
			offset: 0
			sort: ''
			sort_dir: 'asc'
			depth: 0
			org_unit: 1
			#org_type: 1
			#org_name: 'Sitka'

		# Define a function to try searching the public catalogue given a request object.
		trySearching = (request, direction) ->

			#request = $.extend {}, $('.search_settings').data('settings'), request
			#FIXME: the following object is empty and overrides default settings.
			#{
			#depth:    current_depth
			#org_unit: current_location
			#org_name: current_name
			#org_type: current_type
			#}

			# We compare this request with a previously cached request
			# and proceed only if they differ.
			# Our method of comparison is to first stringify the objects into JSON format
			# and then check if the text strings are equal.
			return if @length and JSON.stringify(request) is JSON.stringify(@data 'request')
			@data 'request', request

			$this = @html(content)

			# We now try searching the public catalogue with the new request.
			@parallel 'search results',
				result: eg.openils('search', request)
				ou_tree: eg.openils 'actor.org_tree.retrieve'
			, (x) ->

				# Upon success or not,
				# we will cache the result object and publish it to other plugins.
				@data 'result', x.result
				@publish 'search_results', [x.result]

				# If there are no results,
				# we will show a *zero_hits* message and an optional *search_tips* message.
				if x.result.count is 0
					@append tpl_zero_hits query: x.result.query
					@append rc.search_tips if rc.search_tips
					return

				# Otherwise, we will build page bars to indicate the length of the result list.
				$('.page_bar', @).page_bar {
					request: request
					result:  x.result
				}

				# Finally, we will build the result list.
				$result_list = $('.result_list', @).listview()
				ou_id = Number request.org_unit
				n = 0
				for title_id in x.result.ids

					# Record the maximum tab index.
					maxTab = n if maxTab < ++n

					$result_list.append($(tpl_summary_info title_id: title_id))

					do (title_id, n) ->
						$x = $("#title_id_#{title_id}")

						# For each title, we need to populate three content areas
						# by making three service calls.

						###
						# This sequence populates the areas as soon as each ajax call is completed.
						$x.openils 'title info', 'search.biblio.record.mods_slim.retrieve', title_id
						, (mvr) ->
							return unless mvr
							show_summary_info.call @, mvr
							$result_list.listview 'refresh'

						$x.openils 'title availability', 'search.biblio.record.copy_count',
							id: title_id
							location: ou_id
						, (nc) ->
							return unless nc
							show_copy_counts.call @, nc, request.depth
							$result_list.listview 'refresh'

						$x.openils 'call numbers', 'search.biblio.copy_location_counts.summary.retrieve',
							id: title_id
							org_id: ou_id
							depth: request.depth
						, (cns) ->
							return unless cns
							show_callnumber.call @, cns, x.ou_tree
							$result_list.listview 'refresh'
						###

						#$('.title, .author', $x).prop 'tabindex', n

						# We will use a sequence to populate the areas
						# after all service calls are completed.
						$x.parallel "title ID##{title_id}",
							mvr: eg.openils('search.biblio.record.mods_slim.retrieve', title_id)
							nc: eg.openils('search.biblio.record.copy_count',
								id: title_id
								location: ou_id
							)
							cns: eg.openils('search.biblio.copy_location_counts.summary.retrieve',
								id: title_id
								org_id: ou_id
								depth: request.depth
							)
						, (y) ->
							show_summary_info.call @, y.mvr if y.mvr
							show_copy_counts.call @, y.nc, request.depth if y.nc
							show_callnumber.call @, y.cns, x.ou_tree if y.cns
							$result_list.listview 'refresh'

				# We will focus the user on the first list element.
				$('a.title:first', $result_list).focus()

				# >FIXME:
				# this is a hack to get paging working in title details.
				# Is there a better way?
				$li = switch direction
					when +1 then $this.find('li').first()
					when -1 then $this.find('li').last()
					else $()
				id = get_id $li
				count = 1 + Number(request.offset) + $('li').index $li
				if id and request
					$this.publish 'hold_create', [id, request.org_unit, request.depth, $('img', $li).clone(), x.result.count, count]
				return false

		# Handle keyups for title or author links.
		@on 'keyup', '.title, .author', (e) ->
			switch e.keyCode
				# Click the link if enter key was release.
				when 13 then $(@).click()
			return false

		# Upon the user clicking a title summary area,
		# we will publish a request to create a hold.
		@on 'click', 'li`', (e) =>
			$this = $(@)
			request = $this.data 'request'
			result = $this.data 'result'
			total =  result.count
			offset = Number request.offset

			$li = $(e.currentTarget)

			if $li and (id = get_id $li) and request
				count = offset + 1 + $('li').index $li
				# >FIXME: it would be better for the main js file to load the required modules.
				require ['login_window', 'opac/edit_hold'], ->
					$('#edit_hold').edit_hold()
					$('#login_window').login_window()
					$this.publish 'hold_create', [id, request.org_unit, request.depth, $('img', $li).clone(), total, count]
			return false

		# Upon the plugin receiving an ID (and a possible direction) on *title*
		@subscribe 'title', (title_id, direction) ->
			request = @data 'request'
			result = @data 'result'
			total =  result.count
			actual = result.ids.length
			offset = Number request.offset
			limit =  Number request.limit

			$this_title = $("#title_id_#{title_id}", @)
			return false unless $this_title

			$li = switch direction
				when +1
					# Unless there is no next title on this page
					unless ($li = $this_title.next()).length
						# Search for next page and pick first item on page
						if (offset + limit) < total
							trySearching.call @, $.extend({}, request, offset: offset + limit), direction
					$li
				when -1
					# Unless there is no previous title on this page
					unless ($li = $this_title.prev()).length
						# Search for previous page and pick last item on page
						if 0 <= (offset - limit)
							trySearching.call @, $.extend({}, request, offset: offset - limit), direction
					$li
				else
					$()

			if $li and (id = get_id $li) and request
				count = offset + 1 + $('li').index $li
				@publish 'hold_create', [id, request.org_unit, request.depth, $('img', $li).clone(), total], count
			return false

		# Upon the user clicking an author link,
		# we will extend the recent request with an author search term at zero page offset.
		# We will publish it and try searching the public catalogue with it.
		@on 'click', 'a.author', (e) =>
			$this = $(@)
			request = $this.data 'request'
			author = $('div.author', $(e.currentTarget).closest('li')).text()

			if author and request
				request = $.extend {}, request,
					default_class: 'author'
					term: author
					offset: '0'
					type: 'advanced'

				$this.publish 'search', [request]
				trySearching.call $this, request
			return false

		# Upon receiving a *search* object, we will try searching the public catalogue.
		@subscribe 'search', trySearching

		# Upon receiving a change notice in the search scope,
		@subscribe 'ou', (ou) ->

			# * Cache the new scope parameters
			$.pushState { library: JSON.stringify [ou.id, ou.name, ou.depth, ou.type] }
			current_location = ou.id
			current_name     = ou.name
			current_depth    = ou.depth
			current_type     = ou.type

			# * Do nothing if the plugin is not visible
			return false if not @is ':visible'

			# * Otherwise, extend the current request object with a new scope
			# and publish it on *search*
			if request = @data 'request'
				request = $.extend {}, request,
					org_unit: ou.id
					org_name: ou.name
					depth:    ou.depth
					org_type: ou.type
				@publish 'search', [request]

			return false

		# Upon receiving *clear_data*, we will empty the plugin's content.
		@subscribe 'clear_data', -> @empty()

		# Upon receiving *refresh*, we simply consume it;
		# the content will not change because it is static.
		@refresh -> return false

