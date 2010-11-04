# login_window.js
#
# Provides a login window, and allows other plugins to ensure a user is logged
# in before performing an action.
#
# Code can trigger the login window like:
#
#  $('.login_window').trigger('login_required')
#           or
#  $('.login_window').trigger('login_required', [d]);
#
# Where d is a Deferred object that is called when the user logs in successfully
#
# Alternatively, if a plugin performs an openils request that requires the user
# to be logged in, the eg_api layer will automatically call this plugin, and
# the openils callback will be executed only if the user successfully logs in.

module 'login_window', imports(
	'eg.fieldmapper'
	'eg.eg_api'
	'plugin'
), (fm, eg) ->

	# FIXME: div.error is not needed; error from eg_api layer overrides, I think.
	login_form = '''
	<form class="login_form">
		<div class="error"/>
		<div>
			<label>Username:</label>
			<input type="text" name="username"></input>
		</div><div>
			<label>Password:</label>
			<input type="password" name="password"></input>
		</div><div>
			<button type="submit">Log in</button>
			<button type="reset">Cancel</button>
		</div>
	</form>
	'''
	login_failed = "Login failed: "


	$.fn.login_window = ->

		$plugin = @
		deferreds = []

		# Helper for submit event handler to get defaults.
		get_defaults = ->

			parallel(
				settings: eg.openils 'actor.patron.settings.retrieve'
				ouTree:   eg.openils 'actor.org_tree.retrieve'
			).next (x) ->
				depth    = x.settings['opac.default_search_depth'] or 0
				org_unit = x.settings['opac.default_search_location'] or 1
				org_name = x.ouTree[org_unit].name
				org_type = x.ouTree[org_unit].ou_type
				$plugin.publish 'library', [org_unit, org_name, depth, org_type]


		# Note: The login form is not physically attached to the login window plugin.
		$login_form = $(login_form)

		.refresh ->
			# FIXME: kludgey.
			if eg.logged_in()
				#get_defaults() # get the default search values
				return false

			# User is not logged in; display the login form
			@detach()
			$('input[name=username]', @).val('').focus()
			$('input[name=password]', @).val('')
			$('.error', @).hide()
			$.blockUI { message: @ } # Makes login form not attached to plugin div.
			return false

		.delegate 'button[type=reset]', 'click', cancel = =>
			deferreds = []
			$.unblockUI()
			return false

		.submit submit = ->
			xs = $(@).serializeArray()
			# Submit does not proceed without sane un and pw entries.
			un = xs[0].value
			return false unless un and (un.replace /\s+/, "").length
			pw = xs[1].value
			return false unless pw and (pw.replace /\s+/, "").length

			eg.openils 'auth.session.create', {
				username: un
				password: pw
				type: 'opac'
				org: 1			# TODO: remove hardcode
			}, (session) ->

				# If there is an error,
				# session.ilsevent is 1000 and session.textcode is 'LOGIN_FAILED'
				unless session.ilsevent?
					# FIXME: should session.retrieve be part of session.create?
					eg.openils 'auth.session.retrieve', ->
						# FIXME: search service in eg.api needs auth.session.settings if logged in.
						get_defaults()
						$().publish 'login_event', [un]
						# once logged in, call the list of deferred objects.
						while deferreds.length > 0
							deferreds.pop().call()
						$.unblockUI()
			return false

		.delegate 'input', 'keyup', (e) =>
			switch e.keyCode
				# Upon pressing enter key in input boxes, submit the login form.
				#when 13 then submit.call @
				# Upon pressing escape key in input boxes, cancel the login form.
				when 27 then cancel.call @
			return false

		# The purpose of thelogin window plugin is to respond to a login trigger and a refresh event.
		@plugin('login_window')

		.bind 'login_required', (e, d) ->
			# d is a deferred passed up from the API level that will
			# continue a user action once user is logged in.
			deferreds.push d
			$(@).refresh()
			return false

		# Plugin refresh is passed to refresh event for the login form.
		.refresh ->
			$login_form.refresh()
			return false
