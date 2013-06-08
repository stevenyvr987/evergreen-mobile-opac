
# We define the master jQuery plugin to show the edit hold page,
# which includes title details, holdings details, and hold details.
# The plugin will refresh its content
#
# * If a potential request is received on *hold_create* channel
# * If the user presses next or previous links on the title bar

define [
	'eg/eg_api'
	'template'
	'plugin'
	'opac/cover_art'
	'opac/title_details'
	'opac/holding_details'
	'opac/hold_details'
], (eg, _) -> (($) ->

	# Define the container for the content areas.
	content = '''
	<div class="title_details"></div>
	<div class="holding_details"></div>
	<div class="hold_details"></div>
	'''

	$.fn.edit_hold = ->
		return @ if @plugin()

		# One of the responsibility of the master plugin
		# is to define a navigation bar to allow the user
		# to incrementally scroll through the search result list.
		# The title bar will also show the current number of the title displayed
		# and the total nunmber of titles in the result list.
		title_bar = _.template '''
		<h3>
			Title <span class="count"><%= count %></span> of <span class="total"><%= total %></span>
		</h3>
		<div data-role="controlgroup" data-type="horizontal" class="ui-btn-right">
			<div data-role="button" data-icon="arrow-u" data-mini="false" class="prev"></div>
			<div data-role="button" data-icon="arrow-d" data-mini="false" class="next"></div>
		</div>
		'''

		# We build the title bar with count and total initialized to zero.
		count = total = 0
		title_id = 0

		$('.title_bar', @).html(title_bar count: 0, total: 0)

		# Upon the user clicking the prev or next button in the title bar,
		# we will publish the current *title_id* and a step indicator (+1 or -1) on *title* channel.
		# We will also ensure that the count is properly adjusted
		# and that it will stop adjusting if it reaches the bottom or top boundary.
		.on 'click', 'div', (e) =>
			$target = $(e.currentTarget)

			count = Number $('.count', @).text()

			if $target.hasClass 'prev'
				unless count is 1
					count -= 1
					$('.count', @).text count
				@publish 'opac.title', [title_id, -1]
			else if $target.hasClass 'next'
				unless count is total
					count += 1
					$('.count', @).text count
				@publish 'opac.title', [title_id, +1]
			return false

		# We prepare this container as a plugin.
		$plugin = @plugin('edit_hold')
			.find('.content')
			.html(content).trigger('create')
			.end()

		.subscribe 'opac.title_details', (titles_total, titles_count, titleid, $img) =>
			title_id = titleid

			# We will change to this page unless it is already active.
			$.mobile.changePage @page() unless @ is $.mobile.activePage

			# We will update total and count numbers in the title bar.
			$('.total', @).text total = titles_total
			$('.count', @).text count = titles_count

			$('.title_details', @).title_details(titleid, $img).cover_art()
				.trigger 'create'

		.subscribe 'opac.title_holdings', (titleid, search_ou, search_depth) =>
			eg.openils 'search.config.copy_status.retrieve.all', (status_names) =>
				$('.holding_details', @).holding_details(titleid, search_ou, search_depth, status_names)
					.trigger 'create'

		.subscribe 'opac.title_hold', (titleid) =>
			# We will prepare a title-level hold request.  We set the
			# default pickup library to the user's home ou if it is defined
			# (implies user has logged in).
			$('.hold_details', @).hold_details
				target: titleid # version 1.6 software
				titleid: titleid # version 2.0 software
)(jQuery)
