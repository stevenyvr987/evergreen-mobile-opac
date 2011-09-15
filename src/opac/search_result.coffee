# search_result.coffee
#
# Plugin to provide a summary list of search results. It subscribes to the
# 'search' data type:
#  @publish('search', [search_obj])

module 'opac.search_result', imports(
	'eg.fieldmapper'
	'eg.eg_api'
	'template'
	'plugin'
), (fm, eg, _) ->

	# Define the overall content container for search result list (includes top and bottom page bars).
	content = '''
	<div class="page_bar"></div>
	<ul data-role="listview" data-inset="true" data-split-icon="gear" class="result_list"></ul>
	<div class="page_bar"></div>
	'''

	# Define the zero hits message.
	tpl_zero_hits = _.template '''
	<div class="zero_hits">
		<strong>Sorry, no entries were found for "<%= query %>"</strong>
	</div>
	'''

	# Define the individual list element for a search result.
	#<a class="title" href="#edit_hold" data-rel="dialog" data-transition="slidedown">
	#<a class="title" href="#edit_hold">
	tpl_summary_info = _.template '''
	<li id="title_id_<%= title_id %>">
		<a href="#" class="title">
			<img class="cover_art"></img>
			<div class="info_box">
				<h3 class="info_line">
					<span class="title"></span>
					<span title="Publication date" class="pub_date"></span>
					<span title="Format" class="resource_types"></span>
					<div class="author"></div>
				</h3>
				<p class="status_line">
					<span title="Location and call number of this title" class="callnumber"></span>
					<p><span class="counts_avail"></span> of <span class="counts_total"></span> available</p>
				</p>
			</div>
		</a>
		<a class="author">Search other titles by this author</a>
	</li>
	'''
	show_summary_info = (mvr) ->
		$('span.title', @).text(mvr.title).attr 'title', mvr.title if mvr.title
		$('div.author', @).text(mvr.author).attr 'title', mvr.author if mvr.author
		$('.pub_date', @).text mvr.pubdate if mvr.pubdate
		$('.resource_types', @).text mvr.types_of_resource.join ', ' if mvr.types_of_resource.length

		# ISBN string may be empty, or may contain annotations or multiple values.
		# We pick the first ISBN value, if there is one,
		# and build an image element using the corresponding image.
		# If we get back a 1x1 pixel image, we do not use it.
		$img = $('img', @)
		if isbn = /^(\d+)\D/.exec mvr.isbn
			img = $img.attr('src', "/opac/extras/ac/jacket/small/#{isbn[1]}").get(0)
			# FIXME: natural dimensions are not available until image is retrieved
			#$img.remove() if (not img) or (img.naturalHeight is 1 and img.naturalWidth is 1)
		else
			#$img.remove()

	show_status_line = (nc, depth) ->
		counts = (v for n, v of nc when Number(v.depth) is depth)[0]
		$('.counts_avail', @).text counts.available
		$('.counts_total', @).text counts.count

	# Return ou name / copy location / callnumber as a text string.
	# show_callnumber.call $cns.succeeded(), cns, x.ou_tree
	show_callnumber = (cns, ou) ->
		$cn = $('.callnumber', @)
		if (cns).length
			first = cns[0]
			# Do not show callnumber if all callnumbers do not match first callnumber.
			for cn in cns when cn.callnumber isnt first.callnumber
				return $cn.text 'Multiple locations and call numbers'
			# Do not show ou name if all ou names do not match first ou name.
			# FIXME: also do not show ou name if request ou id corresponds to a leaf of the ou tree.
			ou_name = ou[first.org_id].name
			for cn in cns when ou[cn.org_id].name isnt ou_name
				return $cn.text "#{first.copylocation} / #{first.callnumber}"
			# Do not show copy location if all copy locations do not match first copy location.
			for cn in cns when cn.copylocation isnt first.copylocation
				return $cn.text "#{first.callnumber}"
			$cn.text "#{ou_name} / #{first.copylocation} / #{first.callnumber}"


	# Find title id by looking in given jQuery object or its ancestors.
	# FIXME
	get_id = ($el) ->
		while $el.length > 0
			for c in ($el.attr('id') or '').split(' ')
				m = c.match /^title_id_(\d+)/
				return Number m[1] if m
			$el = $el.parent()
		return


	$.fn.result_summary = ->

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

		# Define a utility function to perform a search
		# for the given request object and under the context of the plugin container.
		doSearch = (request, direction) ->

			#request = $.extend {}, $('.search_settings').data('settings'), request
			#FIXME: the following object is empty and overrides default settings.
			#{
			#depth:    current_depth
			#org_unit: current_location
			#org_name: current_name
			#org_type: current_type
			#}

			# The new request has to differ from the old one.
			return if @length and JSON.stringify(request) is JSON.stringify(@data 'request')

			# Remember the search request.
			@data 'request', request

			$this = @html(content)

			# Make a search request and bind handler for result list.
			@parallel 'search results',
				ou_tree: eg.openils 'actor.org_tree.retrieve'
				result: eg.openils('search', request)
			, (x) ->

				# Remember the search result for myself.
				@data 'result', x.result
				# Publish search result for others.
				@publish 'search_results', [x.result]

				# If there are no results,
				# replace the result list with a 'zero hits' message.
				if x.result.count is 0
					@append tpl_zero_hits query: x.result.query
					@append window.search_tips if window.search_tips
					return

				# Build page bar(s) indicating the length of the result list.
				$('.page_bar', @).page_bar {
					request: request
					result:  x.result
				}

				# Build the result list.
				$result_list = $('.result_list', @).listview()
				ou_id = Number request.org_unit
				n = 0
				for title_id in x.result.ids

					# Record the maximum tab index.
					maxTab = n if maxTab < ++n

					$result_list.append($(tpl_summary_info title_id: title_id))

					do (title_id, n) ->
						$x = $("#title_id_#{title_id}")

						# For each title, we need to make ajax calls to three services
						# and populate three content areas.

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
							show_status_line.call @, nc, request.depth
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

						#$('.title, .author', $x).attr 'tabindex', n

						# This sequence populates the areas after all ajax calls are completed.
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
							show_status_line.call @, y.nc, request.depth if y.nc
							show_callnumber.call @, y.cns, x.ou_tree if y.cns
							$result_list.listview 'refresh'

				# Focus on the first title in the result list.
				$('a.title:first', $result_list).focus()

				# FIXME: A terrible hack to get paging working in title details.
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
		@delegate '.title, .author', 'keyup', (e) ->
			switch e.keyCode
				# Click the link if enter key was release.
				when 13 then $(@).click()
			return false

		# Upon user clicking on thumbnail image,
		@delegate 'img`', 'click', (e) ->
			# show a large version of it
			src = e.target.src.replace 'small', 'large'
			$.mobile.changePage $('#cover_art').find('.content').html("<img src=#{src}>").end()
			return false

		# Upon user clicking on an item of title list,
		# publish a request on the hold create data channel.
		@delegate 'li`', 'click', (e) =>
			$this = $(@)
			request = $this.data 'request'
			result = $this.data 'result'
			total =  result.count
			offset = Number request.offset

			$li = $(e.currentTarget)

			if $li and (id = get_id $li) and request
				count = offset + 1 + $('li').index $li
				# FIXME: perhaps better to have main js file do dynamic loading
				thunk imports('login_window', 'opac.edit_hold'), ->
					$('#edit_hold').edit_hold() unless $('#edit_hold').plugin()
					$('#login_window').login_window() unless $('#login_window').plugin()
					# The main side effect is to publish a hold create request.
					$this.publish 'hold_create', [id, request.org_unit, request.depth, $('img', $li).clone(), total, count]
			return false

		# Upon receiving an ID on the title data channel (with a possible direction)
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
							doSearch.call @, $.extend({}, request, offset: offset + limit), direction
					$li
				when -1
					# Unless there is no previous title on this page
					unless ($li = $this_title.prev()).length
						# Search for previous page and pick last item on page
						if 0 <= (offset - limit)
							doSearch.call @, $.extend({}, request, offset: offset - limit), direction
					$li
				else
					$()

			if $li and (id = get_id $li) and request
				count = offset + 1 + $('li').index $li
				@publish 'hold_create', [id, request.org_unit, request.depth, $('img', $li).clone(), total], count
			return false

		# Handle clicks to author links.
		@delegate 'a.author', 'click', (e) =>
			$this = $(@)
			request = $this.data 'request'
			author = $('div.author', $(e.currentTarget).closest('li')).text()

			if author and request
				# Override recent search request with an author search term at zero offset.
				request = $.extend {}, request,
					default_class: 'author'
					term: author
					offset: '0'
					type: 'advanced'

				$this.publish 'search', [request]
				doSearch.call $this, request
			return false

		# Subscription to get a new search request
		@subscribe 'search', doSearch

		# Subscription to get a change notice in search scope.
		@subscribe 'ou', (ou) ->

			# Upon notification, remember the new scope parameters.
			$.pushState { library: JSON.stringify [ou.id, ou.name, ou.depth, ou.type] }
			current_location = ou.id
			current_name     = ou.name
			current_depth    = ou.depth
			current_type     = ou.type

			return false if not @is ':visible'

			# If plugin is visible,
			# extend the current search request with new scope
			# and publish on search channel.
			if request = @data 'request'
				request = $.extend {}, request,
					org_unit: ou.id
					org_name: ou.name
					depth:    ou.depth
					org_type: ou.type
				@publish 'search', [request]

			return false

		# Empty the plugin's content.
		@subscribe 'clear_data', -> @empty()

		@refresh -> return false


module 'opac.page_bar', imports('template'), (_) ->

	nav_start = '<span data-role="button" data-icon="arrow-l" data-inline="true" class="start">Start</span>'
	nav_prev =  '<span data-role="button" data-icon="arrow-u" data-inline="true" class="prev">Previous</span>'
	nav_next =  '<span data-role="button" data-icon="arrow-d" data-inline="true" class="next">Next</span>'
	nav_end =   '<span data-role="button" data-icon="arrow-r" data-inline="true" class="end">End</span'

	# FIXME: move logic out of template?
	page_number = _.template '''
	<% if (total <= 0) { %>
		<h3>No titles were found.</h3>
	<% } else if (pgtotal === 1 && actual === 1) { %>
	<% } else if (pgtotal === 1) { %>
		<span data-role="button" data-inline="true"><%= actual %> titles were found.</span>
	<% } else if (actual <= 0) { %>
		<span>End of your search.</span>
	<% } else { %>
		<span data-role="button" data-inline="true">Page <%= pgnumber %> of <%= pgtotal %></span>
	<% } %>
	'''

	$.fn.page_bar = (x) ->

		total =  x.result.count
		# Problem: total count does not always equal actual number of search results.
		actual = x.result.ids.length
		offset = Number x.request.offset
		limit =  Number x.request.limit
		pgnumber = 1 + Math.floor offset/limit
		pgtotal = Math.ceil total/limit

		@each ->
			$(@).append page_number {
				total:  total
				actual: actual
				pgnumber: pgnumber
				pgtotal: pgtotal
			}

		if (pgtotal > 1) and (offset isnt 0)
			@each ->
				$(@).append $(nav_start).click ->
					x = $.extend {}, x.request, offset: 0
					$(@).publish 'search', [x]
					return false

		if (pgtotal > 1) and (offset isnt 0)
			@each ->
				$(@).append $(nav_prev).click ->
					x = $.extend {}, x.request, offset: offset - limit
					$(@).publish 'search', [x]
					return false

		if (pgtotal > 1) and ((total - offset) > limit)
			@each ->
				$(@).append $(nav_next).click ->
					x = $.extend {}, x.request, offset: offset + limit
					$(@).publish 'search', [x]
					return false

		# Group all buttons on page bar horizontally.
		@plugin('page_bar')
		.wrapInner('<div data-role="controlgroup" data-type="horizontal"></div>').trigger 'create'
