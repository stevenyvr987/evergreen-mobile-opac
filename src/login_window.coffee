# We define a module to contain a jQuery plugin
# to show an interactive form for inputting user credentials.
# The plugin will respond to submit and cancel events from the user.
#
# The plugin will also respond to 'login_required'.
# Behind the scenes,
# if another plugin makes a service request that requires the user to be logged in,
# the *eg_api* layer will defer the service callback and will trigger the event.
# The plugin will then execute the service callback only if the user successfully logs in.
#
# The login window can be triggered as follows:
#
#  $('.login\_window').trigger('login\_required', [d]);
#
# where d is an optional deferred object
# that will be called when the user logs in successfully.
#
# Once a login session has been started,
# the plugin will publish the username on *login_event*.

define [
	'jquery'
	'eg/eg_api'
	'plugin'
], ($, eg) ->

	# ---
	# Define the content of the form for inputting user credentials,
	# specifically username and password.
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

	# Deferred objects (service callbacks) may number more than one;
	# we will collect them in an array.
	deferreds = []

	# ---
	# Define a function for the submit event handler to get defaults.
	# > FIXME: there doesn't seem to be any subscribers to *library*.
	get_defaults = ->
		parallel(
			settings: eg.openils 'actor.patron.settings.retrieve'
			ouTree:   eg.openils 'actor.org_tree.retrieve'
		).next (x) ->
			depth    = x.settings['opac.default_search_depth'] or 0
			org_unit = x.settings['opac.default_search_location'] or 1
			org_name = x.ouTree[org_unit].name
			org_type = x.ouTree[org_unit].ou_type
			$().publish 'library', [org_unit, org_name, depth, org_type]


	# ---
	# Define the login window plugin.
	$.fn.login_window = ->
		$plugin = @plugin('login_window')

		# Upon the plugin's initial use, we build the content of the login page.
		@find('.content').html(content).trigger('refresh')

		# Upon the user submitting the form,
		# ie, clicking the submit button or pressing the enter key in input boxes,
		.submit submit = ->
			# we first validate the credentials,
			$f = $(@).find('form')
			xs = $f.serializeArray()
			un = xs[0].value
			return false unless un and (un.replace /\s+/, "").length
			pw = xs[1].value
			return false unless pw and (pw.replace /\s+/, "").length

			# and then make a service call with the credentials to try to create a session.
			eg.openils 'auth.session.create', {
				username: un
				password: pw
				type: 'opac'
				org: 1 # TODO: remove hardcode
			}, (session) ->

				# Upon success,
				# ie, session.ilsevent isn't 1000 or session.textcode isn't 'LOGIN_FAILED'
				# we make another service call to try to retrieve the session object
				# (primarily, the patron account info)
				unless session.ilsevent?
					# > FIXME:
					# it would be nicer if this operation was part of the session.create operation;
					# search service in eg.api needs auth.session.settings if logged in.
					eg.openils 'auth.session.retrieve', ->
						# Upon success, we close the login page and empty its content.
						history.back()
						$f
						.find('input[name=username]').val('').end()
						.find('input[name=password]').val('').end()

						# We should also call any deferred service callbacks.
						while deferreds.length > 0
							deferreds.pop().call()

						# We should also notify other plugins that a login has occurred with the given username.
						$().publish 'login_event', [un]

						# > FIXME; not sure whether this is needed anymore.
						get_defaults()
			return false

		# Upon the user cancelling the form,
		# ie, clicking the cancel button or pressing the escape key in input boxes,
		# we close the login page and empty its content.
		.delegate 'button[type=reset]', 'click', cancel = =>
			history.back()
			@find('input[name=username]').val('').end()
			.find('input[name=password]').val('').end()
			# We should also empty the list of deferments.
			deferreds = []
			return false
		.delegate 'input', 'keyup', (e) =>
			switch e.keyCode
				when 27 then cancel.call @
			return false

		# Upon the plugin being notified that a login is required,
		# we open the login page.
		$plugin.bind 'login_required', (e, d) ->
			$.mobile.changePage $(@)
			# We should also add any deferred service callback to our list.
			deferreds.push d
			return false
