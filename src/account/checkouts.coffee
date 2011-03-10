# checkouts.coffee
#
# List the items the user has checked out

module 'account.account_checkouts', imports('eg.eg_api', 'plugin'), (eg) ->
	$.fn.account_checkouts = ->
		$('<div>').checkouts().appendTo @
		@refresh ->
			@publish 'userid', [eg.auth.session.user.id] if eg.auth.session?.user?
			return false


module 'account.checkouts', imports(
	'eg.eg_api'
	'template'
	'plugin'
), (eg, _) ->

	tpl_co_form = '''
	<form>
		<input type="submit" class="renew" name="some" value="Renew selected items"/>
		<input type="submit" class="renew" name="all" value="Renew all"/>
	</form>
	'''
	# FIXME: improve display of copy_status.
	tpl_co_item = (type) ->
		x = if type is 'out'
			'''
			<div class="my_checkout" id="circ_id_<%= circ_id %>">
				<input type="checkbox" name="copy_id" />
				<span class="info_line">
					<span class="title" />
					<span class="author" />
					<span class="types" />
				</span>
				<div class="status_line">
					Due date <span class="due_date" />
					Renewal used <span class="remaining_renewals" />
				</div>
			</div>
			'''
		else
			'''
			<div class="my_checkout" id="circ_id_<%= circ_id %>">
				<input type="checkbox" name="copy_id" />
				<span class="info_line">
					<span class="title" />
					<span class="author" />
					<span class="types" />
				</span>
				<div class="status_line">
					<span class="copy_status"><%= circ_type %></span>
					Due date <span class="due_date" />
					Renewal used <span class="remaining_renewals" />
				</div>
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
				if result.desc
					# A server error is shown to user by eg_api layer.
					return
				else
					# FIXME: we have available result.circ, result.copy, and result.record objects.
					# We could avoid refreshing entire pane and refresh individual status lines instead.
					return

		refresh = ->
			$plugin.ajaxStop ->
				$(@).unbind('ajaxStop').refresh().publish 'checkouts_summary'
				return false

		@plugin('acct_checkouts')

		.subscribe 'userid', ->
			@refresh() if @is ':visible'
			return false

		.subscribe 'logout_event', ->
			@empty()
			return false

		.refresh ->
			@empty().append $list = $ tpl_co_form
			# Hide action buttons until they are needed.
			$renew_some = $('.renew[name="some"]', @).hide()
			$renew_all = $('.renew[name="all"]', @).hide()

			$list.openils 'checkout details', 'actor.user.checked_out.authoritative', (co) ->
				$plugin.publish 'items_checked_out', [co]
				for type, checkouts of co
					for circ_id in checkouts

						$list.prepend (tpl_co_item type)
							circ_id: circ_id
							circ_type: type

						((type, $x) ->
							$('.status_line', $x).openils 'checkout status', 'circ.retrieve.authoritative', circ_id, (circ) ->
								show_status_line.call @.parent(), circ
								$('.info_line', $x).openils 'title info', 'search.biblio.mods_from_copy', circ.target_copy, show_info_line
								# Deactivate items that are not checked out, primarily items overdued.
								if type isnt 'out'
									$x.addClass('inactive')
								# Disable items that cannot be renewed.
								if circ.renewal_remaining is 0
									$x.find(':checkbox').attr 'disabled', true
								# Show relevant action buttons.
								if type is 'out' and circ.renewal_remaining > 0
									if $renew_all.is ':visible' then $renew_some.show() else $renew_all.show()
						) type, $("#circ_id_#{circ_id}")

			return false

		@delegate '.renew[name=some]', 'click', =>
			xids = $('form', $(@)).serializeArray()
			if xids.length
				renew xid.value for xid in xids
				refresh()
			else
				$(@).publish 'notice', ['Nothing was done because no items were selected.']
			return false

		@delegate '.renew[name=all]', 'click', =>
			$xs = $(@).find('input:checkbox:enabled')
			if $xs.length
				$xs.each -> renew $(@).val()
				refresh()
			else
				$(@).publish 'notice', ['Nothing was done because no items can be renewed.']
			return false
