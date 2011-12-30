# We define a module to contain a jQuery plugin
# to list items the user has placed holds on.
# The plugin will behave as follows.
#
# * Respond to submit events fron the user to cancel/suspend/resume hold requests
# * Refresh the list upon receiving *refresh*
# * Publish *holds_summary* to synchronize its summary line

module 'account.holds', imports(
	'eg.eg_api'
	'template'
	'plugin'
), (eg, _) ->


	# ***
	# Define the container of content, a list of holds.
	# The list will be built as an interactive form
	# containing a set of input fields,
	# accompanied by submit buttons to modify the status of a selected group of holds.
	content = '''
	<form>
		<div data-role="fieldcontain">
			<fieldset data-role="controlgroup" />
		</div>
		<div data-role="controlgroup" data-type="horizontal">
			<span class="cancel some"><button type="submit">Cancel selected holds</button></span>
			<span class="cancel all"><button type="submit">Cancel all</button></span>
			<span class="suspend some"><button type="submit">Suspend selected holds</button></span>
			<span class="suspend all"><button type="submit">Suspend all</button></span>
			<span class="resume some"><button type="submit">Activate selected holds</button></span>
			<span class="resume all"><button type="submit">Activate all</button></span>
		</div>
	</form>
	'''

	# Define the template for displaying a hold.
	# The outer container will be identified by *hold_id*.
	# Details of a hold will be shown in an *info_line* and a *status_line*.
	# The hold will be accompanied by a checkbox.
	# If the user selects the checkbox, it will set *hold_id* for *value*.
	tpl_item = _.template '''
	<div class="my_hold" id="hold_id_<%= hold_id %>">
		<input type="checkbox" name="hold_id" value="<%= hold_id %>" id="checkbox_<%= hold_id %>" />
		<label for="checkbox_<%= hold_id %>">
			<span class="info_line" />
			<br />
			<span class="status_line" />
		</label>
	</div>
	'''
	tpl_info_line = _.template '''
	<span class="title"> <%= title %> </span>
	<span class="types"> <%= types %> </span>
	<br />
	<span class="author"> <%= author %> </span>
	'''

	# A hold can have one of several statuses;
	# we will modify how a hold is displayed according to its status.
	tpl_status_line = (o) ->
		a = if o.status is 'Ready for Pickup'
			b = '''
			<span><strong><%= status %></strong> at <%= pickup %></span>
			'''
			c = if o.hold.shelf_time
					'''
					<span>Expires on <strong><%= shelf %></strong></span>
					'''
				else
					''
			'<div>' + b + '</div><div>' + c + '</div>'
		else if o.status is 'In transit'
			b = '''
			<span><%= status %></span>
			'''
			c = '''
			<span>Pick up at <%= pickup %></span>
			'''
			d = if o.hold.shelf_time
					'''
					<span>Expires on <strong><%= shelf %></strong></span>
					'''
				else
					''
			'<div>' + b + '<div></div>' + c + '</div>'
		else
			b = if o.queue_position and o.potential_copies
					'''
					<span>Position <%= posn %> of <%= total %></span>
					'''
				else
					''
			c = if o.potential_copies is 1
					'''
					<span><%= avail %> copy available</span>
					'''
				else if o.potential_copies > 1
					'''
					<span><%= avail %> copies available</span>
					'''
				else
					''
			d = '''
				<span>Pick up at <%= pickup %></span>
				<span>Expires on <%= expire %></span>
				'''
			'<div>' + b + c + '</div><div>' + d + '</div>'
		_.template a


	# ***
	# Define a function to convert a datestamp object into MMDDYY format.
	pad = (x) -> if x < 10 then '0' + x else x
	mmyydd = (x) ->
		"#{pad x.getMonth() + 1}/#{pad x.getDate()}/#{pad x.getFullYear()}"


	# ***
	# Define a function to make a service call
	# to try to cancel a hold given its transaction id.
	# If the cancellation request failed,
	# we will publish a prompt to the user.
	cancel = (hold) ->
		eg.openils 'circ.hold.cancel', hold, (status) ->
			if status is 1
				return
			else
				$().publish 'prompt', ['Hold was not cancelled', status]

	# ***
	# Define a function to make a service call
	# to try to update a hold given its transaction record.
	# If the update request failed,
	# we will publish a prompt to the user.
	update = (hold) ->
		hold_id = hold.id
		eg.openils 'circ.hold.update', hold, (id) ->
			if id is hold_id
				# > FIXME:
				# Upon success, the original ID will be returned.
				# We could update the individual status lines
				# rather than refreshing the holds list.
				return id
			else
				$().publish 'prompt', ['Hold was not updated', id]
				return


	# ***
	# Define the jQuery plugin to show and control the holds list.
	$.fn.holds = ->
		$plugin = @plugin('acct_holds').trigger 'create'

		# Define a list of current holds for logged-in user.
		holds = []

		# Define a function to refresh details list and summary line.
		# We will refresh the list by issuing *refresh*;
		# we will refresh the summary line by publishing *holds_summary*.
		refresh = ->
			$plugin.ajaxStop ->
				$(@).unbind('ajaxStop')
				.refresh()
				.publish 'holds_summary'
				return false

		# Upon receiving *refresh*,
		# we will recreate and refresh the list.
		@refresh ->
			@html(content).trigger 'create'

			# We will hide buttons until they are needed.
			$cancel_some = $('.cancel.some', @).hide()
			$cancel_all = $('.cancel.all"', @).hide()
			$suspend_some = $('.suspend.some', @).hide()
			$suspend_all = $('.suspend.all', @).hide()
			$resume_some = $('.resume.some', @).hide()
			$resume_all = $('.resume.all', @).hide()

			# Define a function to show the buttons as needed.
			show_buttons = (frozen) ->
				if $cancel_all.is ':visible'
					$cancel_some.show()
				else
					$cancel_all.show()
				if frozen
					if $resume_all.is ':visible'
						$resume_some.show()
					else
						$resume_all.show()
				else
					if $suspend_all.is ':visible'
						$suspend_some.show()
					else
						$suspend_all.show()
				return

			# We will make the relevant set of service calls to try to get hold request information.
			# This is a sequence for open-ils v2.0 which will not show database replication error.
			#
			# 1. Get a list of hold IDs
			# 2. Get the org tree if not already cached
			# 2. Get each hold request object
			#
			# We will progressively populate the list as data become available.
			# Moreover, we will modify the visibility of the list and buttons according to hold status.
			$list = $('fieldset', @)
			$list.parallel 'holds list',
				ids: eg.openils 'circ.holds.id_list.retrieve.authoritative'
				ouTree: eg.openils 'actor.org_tree.retrieve'
			, (x) =>
				for id in x.ids
					$list.append $item = $(tpl_item hold_id: id)
					do ($item) ->
						$item.openils "holds details ##{id}", 'circ.hold.details.retrieve.authoritative', id, (o) ->

							# We will cache each holds object in a list
							# so that it may be available if the user wants to update the holds request.
							holds.push o.hold

							$('.info_line', $item).append tpl_info_line
								title: o.mvr.title if o.mvr.title
								author: "#{o.mvr.author}" if o.mvr.author
								types: "#{(o.mvr.types_of_resource).join ', '}" if o.mvr.types_of_resource
							$('.status_line', $item).append (tpl_status_line o)
								status: o.status if o.status
								posn:	o.queue_position
								total:	o.total_holds
								avail:	o.potential_copies
								pickup: "#{x.ouTree[o.hold.pickup_lib].name}" if o.hold.pickup_lib
								expire: if o.hold.expire_time then "#{mmyydd o.hold.expire_time}" else ''
								shelf: if o.hold.shelf_time then "#{mmyydd o.hold.shelf_time}" else ''

							# * Grey out frozen holds
							$('input, .info_line, .status_line', $item).addClass if o.hold.frozen then 'inactive' else 'active'
							# * Show only relevant submit buttons
							show_buttons o.hold.frozen
							$item.trigger 'create'
			return false

		# Upon the user clicking one of the *some* buttons,
		# we will find the selected DOM elements
		# and cancel/suspend/resume the related holds asynchronously.
		# We also will refresh the list.
		# If the user clicked the button without making a selection,
		# we will publish a notice instead.
		@delegate '.cancel.some', 'click', ->
			xids = $(@).closest('form').serializeArray()
			if xids.length
				cancel xid.value for xid in xids
				refresh()
			else
				$(@).publish 'notice', ['Nothing was done because no holds were selected.']
			return false
		@delegate '.suspend.some', 'click', update_some = ->
			suspend = $(@).hasClass 'suspend'
			xids = $(@).closest('form').serializeArray()
			if xids.length
				for xid in xids
					for hold in holds when hold.id is parseInt xid.value
						hold.frozen = suspend
						update hold
						break
				refresh()
			else
				$(@).publish 'notice', ['Nothing was done because no holds were selected.']
			return false
		@delegate '.resume.some', 'click', update_some

		# Upon the user clicking one of the *all* buttons,
		# we do as above, except the details of finding holds differ.
		# Here, we will find the set as jQuery objects.
		@delegate '.cancel.all', 'click', ->
			$xs = $(@).closest('form').find('input:checkbox')
			if $xs.length
				$xs.each -> cancel $(@).val()
				refresh()
			else
				$(@).publish 'notice', ['Nothing was done because no holds can be cancelled.']
			return false
		@delegate '.suspend.all', 'click', update_all = ->
			suspend = $(@).hasClass 'suspend'
			$xs = $(@).closest('form')
				.find(".my_hold #{if suspend then '.active' else '.inactive'}")
				.closest 'input:checkbox'
			if $xs.length
				$xs.each ->
					for hold in holds when hold.id is parseInt $(@).val()
						hold.frozen = suspend
						update hold
						break
				refresh()
			else
				$(@).publish 'notice', if suspend then ['Nothing was done because no active holds were found to suspend.'] else ['Nothing was done because no suspended holds were found to activate.']
			return false
		@delegate '.resume.all', 'click', update_all
