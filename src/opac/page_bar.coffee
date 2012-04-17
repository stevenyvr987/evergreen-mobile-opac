# We define a custom jQuery plugin to navigate between pages of search results.

define [
	'jquery'
	'template'
	'plugin'
], ($, _) ->

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
			$(@).append page_number
				total:  total
				actual: actual
				pgnumber: pgnumber
				pgtotal: pgtotal

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
