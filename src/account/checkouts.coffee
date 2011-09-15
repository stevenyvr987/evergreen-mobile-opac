# checkouts.coffee
#
# List the items the user has checked out

module 'account.checkouts', imports(
	'eg.eg_api'
	'template'
	'plugin'
), (eg, _) ->

	tpl_form = '''
	<form>
		<div data-role="fieldcontain">
			<fieldset data-role="controlgroup" />
		</div>
		<div data-role="controlgroup" data-type="horizontal">
			<span class="renew some"><button type="submit">Renew selected items</button></span>
			<span class="renew all"><button type="submit">Renew all</button></span>
		</div>
	</form>
	'''
	tpl_item = (type) ->
		x = if type is 'out'
			'''
			<div class="my_checkout" id="circ_id_<%= circ_id %>">
				<input type="checkbox" name="copy_id" value="<%= circ_id %>" id="checkbox_<%= circ_id %>" />
				<label for="checkbox_<%= circ_id %>">
					<span class="info_line">
						<span class="title" />
						<span class="types" />
						<br />
						<span class="author" />
					</span>
					<br />
					<span class="status_line">
						Due date <span class="due_date" />
						Renewal used <span class="remaining_renewals" />
					</span>
				</label>
			</div>
			'''
		else
			'''
			<div class="my_checkout" id="circ_id_<%= circ_id %>">
				<input type="checkbox" name="copy_id" value="<%= circ_id %>" id="checkbox_<%= circ_id %>" />
				<label for="checkbox_<%= circ_id %>">
					<span class="info_line">
						<span class="title" />
						<span class="types" />
						<br />
						<span class="author" />
					</span>
					<br />
					<span class="status_line">
						<span class="copy_status"><%= circ_type %></span>
						Due date <span class="due_date" />
						Renewal used <span class="remaining_renewals" />
					</span>
				</label>
			</div>
			'''
		_.template x

	show_info_line = (mvr) ->
		$('.title', @).text mvr.title if mvr.title
		$('.author', @).text "#{mvr.author}" if mvr.author
		$('.types', @).text "#{(mvr.types_of_resource).join ', '}" if mvr.types_of_resource

	pad = (x) -> if x < 10 then '0' + x else x
	datestamp = (x) ->
		"#{pad x.getMonth() + 1}/#{pad x.getDate()}/#{x.getFullYear()}"

	show_status_line = (circ) ->
		$('.due_date', @).text datestamp circ.due_date
		$('.remaining_renewals', @).text circ.renewal_remaining
		$('input:checkbox', @).val circ.target_copy


	$.fn.checkouts = ->

		$plugin = @

		# Use ajax to renew a circ given a copy id.
		renew = (xid) ->
			eg.openils 'circ.renew', parseInt(xid), (result) ->
				###
				if result.desc
					# A server error is shown to user by eg_api layer.
					return
				else
					# FIXME: we have available result.circ, result.copy, and result.record objects.
					# We could avoid refreshing entire pane and refresh individual status lines instead.
					return
				###

		refresh = ->
			$plugin.ajaxStop ->
				$(@).unbind('ajaxStop').refresh().publish 'checkouts_summary'
				return false

		@plugin('acct_checkouts').trigger('create')

		.refresh ->
			@html(tpl_form).trigger 'create'
			$list = $('fieldset', @)

			# Hide action buttons until they are needed.
			$renew_some = $('.renew.some', @).hide()
			$renew_all = $('.renew.all', @).hide()

			$list.openils 'checkout details', 'actor.user.checked_out.authoritative', (co) ->
				$plugin.publish 'items_checked_out', [co]
				for type, checkouts of co
					for circ_id in checkouts

						$list.prepend $item = $ (tpl_item type)
							circ_id: circ_id
							circ_type: type

						do (type, $item) ->
							$('.status_line', $item).openils "checkout status for ##{circ_id}", 'circ.retrieve.authoritative', circ_id, (circ) ->
								show_status_line.call $item, circ
								$('.info_line', $item).openils "title info for ##{circ.target_copy}", 'search.biblio.mods_from_copy', circ.target_copy, (mvr) ->
									show_info_line.call $item, mvr
								# Deactivate items that are not checked out, primarily items overdued.
								if type isnt 'out'
									$('input, .info_line, .status_line', $item).addClass 'inactive'
								# Disable items that cannot be renewed.
								if circ.renewal_remaining is 0
									$item.find(':checkbox').attr 'disabled', true
								# Show relevant action buttons.
								if type is 'out' and circ.renewal_remaining > 0
									if $renew_all.is ':visible' then $renew_some.show() else $renew_all.show()
								$item.trigger 'create'
			return false

		@delegate '.renew.some', 'click', ->
			xids = $(@).closest('form').serializeArray()
			if xids.length
				renew xid.value for xid in xids
				refresh()
			else
				$(@).publish 'notice', ['Nothing was done because no items were selected.']
			return false

		@delegate '.renew.all', 'click', ->
			$xs = $(@).closest('form').find('input:checkbox:enabled')
			if $xs.length
				$xs.each -> renew $(@).val()
				refresh()
			else
				$(@).publish 'notice', ['Nothing was done because no items can be renewed.']
			return false
