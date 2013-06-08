# Define a custom jQuery plugin to show a form
# to allow the user to place a title-level hold.
# Default pickup location is specified by hold request.
# Otherwise, set it to ou id of last copy listed.
# >FIXME: would be good to mark these circ_ou's in the ou selection list.

define [
	'eg/eg_api'
	'opac/ou_tree'
	'plugin'
], (eg, OU) -> (($) ->

	$.fn.hold_details = (hold) ->

		# The content for the plugin is a form to enable the user
		# to place a title-level hold on the current item.
		# The main input element is a selector to allow the user to select the pickup library.
		$form = $ '''
		<form class="place_hold" data-ajax="false">
			<!--div data-role="fieldcontain">
				<label for="edit_hold_org_unit">Hold a copy of this title at</label>
				<span id="edit_hold_org_unit" class="org_unit_selector"></span>
			</div-->
			<fieldset class="ui-grid-a">
				<div class="ui-block-a"><a href="#" data-role="button" data-rel="back" class="reset">Cancel</a></div>
				<div class="ui-block-b"><a href="#" data-role="button" data-rel="back" class="submit">Place Hold</a></div>
			</fieldset>
		</form>
		'''

		hide_form = -> false

		# Define a function to handle the submit event.
		place_hold = ->

			# Prepare the hold request based on data read from the hold screen
			# and the place hold form.
			#$.extend hold, $('form.place_hold', @).serializeObject()

			# Calculate the selection depth for hold targeting
			#hold.selection_depth = OU.id_depth window.query.ol if window.query?.ol?

			# Request to update or create a hold.
			# >FIXME: need better success message.
			if hold.id
				eg.openils 'circ.hold.update', hold, (result) =>
					if ok = typeof result isnt 'object'
						# Publish notice of successful hold update to user
						@publish 'notice', ['Hold updated']
						# and to other plugins.
						@publish 'account.holds_summary', [hold.id]
					else
						@publish 'prompt', ['Hold update failed', "#{result[0].desc}"]

			else
				eg.openils 'circ.title_hold.is_possible', hold, (possible) =>

					# If the hold is unfillable but it's possible to place it anyways, we will do it.
					# This is a temporary strategy to ease development.
					if possible?.success or (force = possible?.place_unfillable)

						if force
							reason = """
								The requested hold cannot currently be filled.
								(#{possible?.last_event?.desc or possible?.last_event?.textcode})
								Automatically forcing the hold request
								since you have permission to create the hold.
								"""
							@publish 'prompt', ['Hold request failed', reason]

						# Echo the returned depth in the hold request
						hold.selection_depth = possible.depth

						eg.openils 'circ.holds.create', hold, (result) =>
							if ok = typeof result isnt 'object'
								# Publish notice of successful hold creation to user
								@publish 'notice', ['Hold created']
								# and to other plugins.
								@publish 'account.holds_summary', [hold]
							else
								@publish 'prompt', ['Hold request failed', "#{result[0].desc}"]

					# The real strategy for unfillable holds that can be placed
					# is to show a prompt and enable the user to choose to force the hold creation.
					else if possible?.place_unfillable
						reason = """
							The requested hold cannot currently be filled.
							(#{possible?.last_event?.desc or possible?.last_event?.textcode})
							You have permission to create the hold anyway,
							but should only do so if you believe the hold will eventually be filled.
							Would you like to create the hold?
							"""
						@publish 'prompt', ['Hold request failed', reason]

					else
						reason = """
							This title is not eligible for a hold.
							(#{possible?.last_event?.desc or possible?.last_event?.textcode})
							"""
						@publish 'prompt', ['Hold request failed', reason]
			return false

		# We create the place hold form for the plugin.
		@html($form).trigger 'create'

		# We build a selector for the form to show a list of pickup libraries.
#		$('.org_unit_selector', @).ou_tree
#			name: 'pickup_lib'
#			all: false
#			selected: Number hold.pickup_lib
#			indent: '. '
#			focus: true

		# Upon the user clicking the submit button, we will place a hold.
		$('a.submit', @).bind 'click', => place_hold.call @

		# >FIXME: esc key does not work for jQM
		@on 'keyup', 'form.place_hold', (e) =>
			switch e.keyCode
				when 27 then hide_form.call @
			return false

		# We define some keyboard shortcuts:
		@on 'keyup', 'button', (e) =>
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
)(jQuery)
