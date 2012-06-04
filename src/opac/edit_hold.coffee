
# We define the master jQuery plugin to show the edit hold page,
# which includes title details, holdings details, and hold details.
# The plugin will refresh its content
#
# * If a potential request is received on *hold_create* channel
# * If the user presses next or previous links on the title bar

define [
	'jquery'
	'eg/eg_api'
	'eg/auth'
	'template'
	'plugin'
	'opac/cover_art'
	'opac/title_details'
	'opac/holding_details'
	'opac/hold_details'
], ($, eg, auth, _) ->

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
		<div class="ui-btn-right">
			<div data-role="button" data-icon="arrow-u" class="prev"></div>
			<div data-role="button" data-icon="arrow-d" class="next"></div>
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


		# Define the container for the three main areas of content.
		content = '''
		<ul class="title_details" data-role="listview" data-inset="true"></ul>
		<div class="holding_details"></div>
		<div class="hold_details"></div>
		'''
		$('.content', @).html(content)

		# Define a function to show content.
		show_content = (hold, search_ou, search_depth, $img) ->
			$('.title_details', @).title_details(hold.titleid, $img).cover_art()
			$('.hold_details', @).hold_details(hold)

			eg.openils 'search.config.copy_status.retrieve.all', (status_names) =>
				$('.holding_details', @).holding_details(hold, search_ou, search_depth, status_names)
			# >FIXME:
			#
			# * We should get these objects once per browser session.

		# We prepare this container as a plugin.
		@plugin('edit_hold')

		# Upon receiving a potential request on *hold_create* channel
		.subscribe 'opac.hold_create', (titles_total, titles_count, titleid, search_ou, search_depth, $img) =>
			title_id = titleid

			# We will build a title-level hold request
			# and set the default pickup library
			# to the user's home ou if it is defined
			# (implies user has logged in).
			hold =
				target: titleid # version 1.6 software
				titleid: titleid # version 2.0 software
				hold_type: 'T' # default type is 'title-level'
				selection_depth: 0
				pickup_lib: Number auth.session.user.home_ou

			# We will show content based on the hold request.
			show_content.call @, hold, search_ou, search_depth, $img

			# We will update total and count numbers in the title bar.
			$('.total', @).text total = titles_total
			$('.count', @).text count = titles_count

			# We will change to this page unless it is already active.
			$.mobile.changePage @page() unless @ is $.mobile.activePage

		# Upon receiving a potential request on *hold_update* channel,
		# we will show its content, but currently the plugin doesn't have controls to update holds.
		.subscribe 'opac.hold_update', (hold) =>
			show_content.call @, hold
