
# We define the master jQuery plugin to show the edit hold page,
# which includes title details, holdings details, and hold details.
# The plugin will refresh its content
#
# * If a potential request is received on *hold_create* channel
# * If the user presses next or previous links on the nav bar

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
				$('.title_details', @).title_details($img).cover_art()
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
				pickup_lib: Number auth.session.user.home_ou

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
