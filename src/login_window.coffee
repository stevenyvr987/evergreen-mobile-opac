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
	#		<div class="error"></div>
	content = '''
		<form class="login_form">
			<div data-role="fieldcontain">
				<label for="login_un">Username</label>
				<input type="text" id="login_un" name="username" />
			</div>
			<div data-role="fieldcontain">
				<label for="login_pw">Password</label>
				<input type="password" id="login_pw" name="password" value="" />
			</div>
			<div class="ui-grid-a">
				<div class="ui-block-a">
					<button type="reset">Cancel</button>
				</div>
				<div class="ui-block-b">
					<button type="submit">Log in</button>
				</div>
			</div>
		</form>
	'''
	login_failed = "Login failed: "


	$.fn.login_window = ->

		$plugin = @plugin('login_window')

		deferreds = []

		# Define a helper function for the submit event handler to get defaults.
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

		# Build first-time content
		@find('.content').html(content).page().end()

		# Upon the user cancelling login
		.delegate 'button[type=reset]', 'click', cancel = =>
			# Reset deferreds list
			deferreds = []
			# Close the login dialog
			@dialog('close')
			# Blank out any credentials that user may have entered
			.find('input[name=username]').val('').end()
			.find('input[name=password]').val('').end()
			return false

		# Upon the user submitting login credentials
		.submit submit = ->
			# Get the credentials from the login form
			$f = $(@).find('form')
			xs = $f.serializeArray()
			# Do not proceed without sane credentials
			un = xs[0].value
			return false unless un and (un.replace /\s+/, "").length
			pw = xs[1].value
			return false unless pw and (pw.replace /\s+/, "").length

			# Try to create a session with the credentials
			eg.openils 'auth.session.create', {
				username: un
				password: pw
				type: 'opac'
				org: 1			# TODO: remove hardcode
			}, (session) ->

				# Upon success (session.ilsevent isn't 1000 or session.textcode isn't 'LOGIN_FAILED')
				unless session.ilsevent?
					# Retrieve the session object (primarily, the patron account info)
					# FIXME: admittedly this operation could be part of the session.create operation.
					eg.openils 'auth.session.retrieve', ->
						# FIXME: search service in eg.api needs auth.session.settings if logged in.
						get_defaults()
						# Call the list of deferred objects.
						while deferreds.length > 0
							deferreds.pop().call()
						# Close the login dialog
						$plugin.dialog 'close'
						# blank out the credentials user has entered on the login form
						$f
						.find('input[name=username]').val('').end()
						.find('input[name=password]').val('').end()
						# Notify others that login has occurred with the given username
						$().publish 'login_event', [un]
			return false

		# Upon the plugin receiving notice that a login is required
		$plugin.bind 'login_required', (e, d) ->
			# Push a deferrment passed up from the API level that will
			# continue a user action once user is logged in.
			deferreds.push d
			# Open the login dialog to enable to enter credentials
			$.mobile.changePage $(@)
			return false

		# Upon pressing escape key in input boxes, the login form is cancelled.
		# (Also, upon pressing enter key in input boxes, the login form is submitted,
		# but this is a natural behaviour of the form and so doesn't require any code below.)
		.delegate 'input', 'keyup', (e) =>
			switch e.keyCode
				when 27 then cancel.call @
			return false
