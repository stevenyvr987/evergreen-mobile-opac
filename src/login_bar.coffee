# We define a custom jQuery plugin to define an interactive login bar.  The
# plugin will show a button to either log in or log out and will indicate who
# is currently logged in.  The plugin will respond to click events from the
# user, and will subscribe to custom login and logout events.

define [
	'template'
	'plugin'
], (_) -> (($) ->

	# Define the HTML template for the login button.
	tpl_login = _.template '''
	<div>
		<span data-role="button" data-icon="forward" data-inline="true" class="login">
			Log in to see account details
		</span>
	</div>
	'''

	# Define the HTML template for the logout button.
	# The template also indicates who is currently logged in.
	tpl_logout = _.template '''
	<div>
		<span data-role="button" data-icon="back" data-inline="true" class="logout">
			Log out. You are currently logged in as <%= username %>
		</span>
	</div>
	'''

	# Define the plugin for the login bar.
	$.fn.login_bar = ->

		@plugin('login_bar')

		# Upon the plugin's initial use, we create the login button.
		.html(tpl_login {}).trigger('create')

		# Upon the user clicking the login button,
		# we show a login window.
		.on 'click', '.login', ->
			# > The login window is defined as a separate jQuery plugin module.
			# Since the user may not log in at all during an OPAC session,
			# we import the module on demand.
			#
			# > FIXME: this plugin is referencing the login window, which is
			# another plugin, by its id, but for better maintainability, a
			# plugin should not know another plugin's id.
			require ['login_window'], -> $.mobile.changePage $('#login_window').login_window()
			return false

		# Upon the start of a session,
		# we show the logout button with the username as the login status.
		.subscribe 'session.login', (un) ->
			$(@).html(tpl_logout username: un).trigger 'create'
			return false

		# Upon the user clicking the logout button,
		# we try to delete the user session by making the relevant service call.
		.on 'click', '.logout', ->
			# A service call requires the Evergreen API module, which is imported upon demand.
			require ['eg/eg_api'], (eg) -> eg.openils 'auth.session.delete'
			return false

		# Upon the end of a session,
		# we show the login button again.
		.subscribe 'session.logout', ->
			$(@).html(tpl_login {}).trigger 'create'
			return false
)(jQuery)
