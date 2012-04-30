# Define a custom jQuery plugin to show a form
# to allow the user to place a title-level hold.
# Default pickup location is specified by hold request.
# Otherwise, set it to ou id of last copy listed.
# >FIXME: would be good to mark these circ_ou's in the ou selection list.

define [
	'jquery'
	'eg/eg_api'
	'template'
	'plugin'
	'opac/ou_tree'
], ($, eg, _) ->

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
			$plugin = @closest '.plugin'
			if hold.id
				eg.openils 'circ.hold.update', hold, (result) =>
					if ok = typeof result isnt 'object'
						# Publish notice of successful hold update to user
						$plugin.publish 'notice', ['Hold updated']
						# and to other plugins.
						$plugin.publish 'account.holds_summary', [hold.id]
					else
						$plugin.publish 'prompt', ['Hold update failed', "#{result[0].desc}"]

			else
				eg.openils 'circ.title_hold.is_possible', hold, (possible) =>
					if possible?.success
						eg.openils 'circ.holds.create', hold, (result) =>
							if ok = typeof result isnt 'object'
								# Publish notice of successful hold creation to user
								$plugin.publish 'notice', ['Hold created']
								# and to other plugins.
								$plugin.publish 'account.holds_summary', [hold]
							else
								$plugin.publish 'prompt', ['Hold request failed', "#{result[0].desc}"]
					else
						if possible?.last_event?.desc
							$plugin.publish 'prompt', ['Hold request failed', "#{possible.last_event.desc}"]
						else
							$plugin.publish 'prompt', [
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
