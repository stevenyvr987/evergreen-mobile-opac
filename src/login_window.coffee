# We define a jQuery plugin to show an interactive form for inputting user
# credentials.  The plugin will respond to submit and cancel events from the
# user.
#
# The plugin will also subscribe to 'session.required'.  Behind the scenes, if
# another plugin makes a service request that requires the user to be logged
# in, the *eg_api* module will defer the service callback and will publish the
# deferred callback to the topic.  The plugin will then execute the service
# callback only if the user successfully logs in.
#
# Once a session has been started, the plugin will publish the username on
# *session.login*.

define [
	'eg/eg_api'
	'plugin'
], (eg) -> (($) ->

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

	# Deferred service callbacks may number more than one;
	# we will collect them in an array.
	deferreds = []


	# ---
	# Define the login window plugin.
	$.fn.login_window = ->
		return @ if @plugin()
		$login_w = @plugin('login_window')

		# Upon the plugin's initial use, we build the content of the login page.
		@find('.content').html(content).trigger('refresh')

		# Upon the user submitting the form,
		# ie, clicking the submit button or pressing the enter key in input boxes,
		.submit submit = ->

			# The login form provides username and password credentials.
			credentials = ($f = $('form', @)).serializeArray()

			# Try to make a service call with the credentials to try to create a session.
			# The attempt aborts if the credentials are not valid (eg, blank text)
			eg.openils 'auth.session.create',
				username: un = credentials[0].value
				password: pw = credentials[1].value
				type: 'opac'
				org: 1 # TODO: remove hardcode
			, (resp) ->
				# Upon success, we close the login page and empty its input fields.
				history.back()
				$('input', $f).val('').end()

				# We should also call any deferred service callbacks.
				while deferreds.length > 0
					deferreds.pop().call()

				# We should also notify other plugins that a login has occurred
				# with the given username.
				$().publish 'session.login', [un]
				return
			return false

		# Upon the user cancelling the form,
		# ie, clicking the cancel button or pressing the escape key in input boxes,
		# we close the login page and empty its content.
		.on 'click', 'button[type=reset]', cancel = =>
			history.back()
			@find('input[name=username]').val('').end()
			.find('input[name=password]').val('').end()
			# We should also empty the list of deferments.
			deferreds = []
			return false
		.on 'keyup', 'input', (e) =>
			switch e.keyCode
				when 27 then cancel.call @
			return false

		# Upon the plugin being notified that a login is required,
		# we open the login page.
		$login_w.subscribe 'session.required', (d) ->
			$.mobile.changePage $(@)
			# We should also add any deferred service callback to our list.
			deferreds.push d
			return false
)(jQuery)
