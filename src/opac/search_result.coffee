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

	summary_list = '''
	<div class="summary_bar"></div>
	<div class="summary_list"></div>
	'''

	tpl_summary_info = _.template '''
	<div class="summary_info" id="title_id_<%= title_id %>">
		<div class="info_line">
			<a class="link title" title="View details and place a hold for this title" />
			<a class="link author" title="Search other titles by this author" />
			<span class="pub_date" />
			<span class="resource_types" />
		</div>
		<div class="status_line">
			<span class="counts_avail" /> of <span class="counts_total" /> available.
			<span class="callnumber" title="Location and call number of this title" />
		</div>
	</div>
	'''
	show_info_line = (mvr) ->
		$('.title', @).text          mvr.title
		$('.author', @).text         mvr.author
		$('.pub_date', @).text       mvr.pubdate
		$('.resource_types', @).text mvr.types_of_resource.join ', '

	show_status_line = (nc, depth) ->
		counts = (v for n, v of nc when Number(v.depth) is depth)[0]
		$('.counts_avail', @).text counts.available
		$('.counts_total', @).text counts.count

	# Return ou name / copy location / callnumber as a text string.
	# show_callnumber.call $cns.succeeded(), cns, x.ou_tree
	show_callnumber = (cns, ou) ->
		if (cns).length
			first = cns[0]
			# Do not show callnumber if all callnumbers do not match first callnumber.
			for cn in cns when cn.callnumber isnt first.callnumber
				return ''
			# Do not show ou name if all ou names do not match first ou name.
			# FIXME: also do not show ou name if request ou id corresponds to a leaf of the ou tree.
			ou_name = ou[first.org_id].name
			for cn in cns when ou[cn.org_id].name isnt ou_name
				return @text "#{first.copylocation} / #{first.callnumber}"
			# Do not show copy location if all copy locations do not match first copy location.
			for cn in cns when cn.copylocation isnt first.copylocation
				return @text "#{first.callnumber}"
			@text "#{ou_name} / #{first.copylocation} / #{first.callnumber}"


	# Find title id by looking in given element or its ancestors.
	# FIXME
	get_id = (el) ->
		while el.length > 0
			for c in (el.attr('id') or '').split(' ')
				m = c.match /^title_id_(\d+)/
				return Number m[1] if m
			el = el.parent()
		return


	$.fn.result_summary = ->

		current_location = ''
		current_name = ''
		current_depth = ''
		current_type = ''

		maxTab = 0

		$result_list = @plugin('search_settings')
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


		# Subscribe to the search channel.
		# Upon receiving a request on the channel, initiate a search.
		@subscribe 'search', (request) ->

			#request = $.extend {}, $('.search_settings').data('settings'), request
			#FIXME: the following object is empty and overrides default settings.
			#{
			#depth:    current_depth
			#org_unit: current_location
			#org_name: current_name
			#org_type: current_type
			#}

			# The new request has to differ from the old one.
			return if JSON.stringify(request) is JSON.stringify($result_list.data 'request')

			# Remember the search request.
			# FIXME: as it turns out, $('.search_settings') and $result_list are the same DOM element.
			#$('.search_settings').data 'settings', request
			$result_list.data 'request', request

			$result_list.html summary_list

			# Make a search request and bind handler for result list.
			$result_list.find('div.summary_bar').parallel 'search results',
				ou_tree: eg.openils 'actor.org_tree.retrieve'
				result: eg.openils('search', request)
			, (x) ->

				@summary_bar {
					request: request
					result:  x.result
				}

				# Remember the search result for myself.
				# Publish search result for others.
				$result_list.data 'result', x.result
				$result_list.publish 'search_results', [x.result]

				$summary_info = $result_list.find('div.summary_list')
				ou_id = Number request.org_unit
				n = 0
				for title_id in x.result.ids

					# Record the maximum tab index.
					maxTab = n if maxTab < ++n

					$summary_info.append tpl_summary_info { title_id: title_id }
					((title_id, tabindex) ->
						$x = $("#title_id_#{title_id}")
						$('.title, .author', $x).attr 'tabindex', tabindex
						$('.info_line', $x).openils 'title info', 'search.biblio.record.mods_slim.retrieve', title_id, show_info_line

						$('.status_line', $x).openils 'title availability', 'search.biblio.record.copy_count',
							id: title_id
							location: ou_id
						, (nc) -> show_status_line.call @, nc, request.depth

						$('.callnumber', $x).openils 'call numbers', 'search.biblio.copy_location_counts.summary.retrieve',
							id: title_id
							org_id: ou_id
							depth: request.depth
						, (cns) -> show_callnumber.call @, cns, x.ou_tree
					) title_id, n
				$first_title = $('.title:first', $summary_info).focus()
				return

		# Handle keyups for title or author links.
		@delegate '.title, .author', 'keyup', (e) ->
			switch e.keyCode
				# Click the link if enter key was release.
				when 13 then $(@).click()
			return false

		# Handle clicks to title or author links.
		@click (e) ->

			$link = $(e.target)
			id = get_id $link
			$plugin = $(e.currentTarget)
			search = $plugin.data 'request'

			if $link.hasClass('title') and id and search
				thunk imports('login_window', 'opac.edit_hold'), ->
					# FIXME: these plugins should not be aware of element identifiers.
					$('#edit_hold').edit_hold() unless $('#edit_hold').plugin()
					$('#login_window').login_window() unless $('#login_window').plugin()
					$plugin.publish 'hold_create', [id, search.org_unit, search.depth]

			else if $link.hasClass('author') and x = $link.text()
				$plugin.publish 'search', [$.extend {}, $plugin.data('settings'),
					default_class: 'author'
					term: x
					offset: 0
					type: 'advanced'
				]
			return false

		# Subscribe to the ou channel to get a change notice in search scope.
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
			if request = $result_list.data 'request'
				request = $.extend {}, request,
					org_unit: ou.id
					org_name: ou.name
					depth:    ou.depth
					org_type: ou.type
				@publish 'search', [request]

			return false

		# FIXME: is this needed?
		@subscribe 'clear_data', ->
			$result_list.removeData 'request'
			return false

		@refresh ->
			return false


module 'opac.summary_bar', imports('template'), (_) ->

	nav_start = '<span class="link start" title="Go to first page">    |<<  </span>'
	nav_prev =  '<span class="link prev"  title="Go to previous page">  <<  </span>'
	nav_next =  '<span class="link next"  title="Go to next page">      >>  </span>'
	# FIXME: not done; probably not possible to calculate last page.
	nav_end =   '<span class="link end"   title="Go to last page">      >>| </span>'

	# FIXME: move logic out of template?
	page_number = _.template '''
	<% if (total <= 0) { %>
		<span>No titles were found.</span>
	<% } else if (pgtotal === 1 && actual === 1) { %>
		<span><%= actual %> title was found.</span>
	<% } else if (pgtotal === 1) { %>
		<span><%= actual %> titles were found.</span>
	<% } else if (actual <= 0) { %>
		<span>End of your search.</span>
	<% } else { %>
		<span>Page <%= pgnumber %> of <%= pgtotal %></span>
	<% } %>
	'''

	$.fn.summary_bar = (x) ->

		total =  x.result.count
		# Problem: total count does not always equal actual number of search results.
		actual = x.result.ids.length
		offset = Number x.request.offset
		limit =  Number x.request.limit
		pgnumber = 1 + Math.floor offset/limit
		pgtotal = Math.ceil total/limit

		if (pgtotal > 1) and (offset isnt 0)
			@each ->
				$(@).append $(nav_start).click ->
					x = $.extend {}, x.request, { offset: 0 }
					$(@).publish 'search', [x]
					return false

		if (pgtotal > 1) and (offset isnt 0)
			@each ->
				$(@).append $(nav_prev).click ->
					x = $.extend {}, x.request, { offset: offset - limit }
					$(@).publish 'search', [x]
					return false

		@each ->
			$(@).append page_number {
				total:  total
				actual: actual
				pgnumber: pgnumber
				pgtotal: pgtotal
			}

		if (pgtotal > 1) and ((total - offset) > limit)
			@each ->
				$(@).append $(nav_next).click ->
					x = $.extend {}, x.request, { offset: offset + limit }
					$(@).publish 'search', [x]
					return false

		return @
