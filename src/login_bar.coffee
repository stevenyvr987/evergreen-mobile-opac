# login_bar.coffee
#
# Allows the user to log in.
# Informs the user of their username, and allows them to log out.

module 'login_bar', imports('template', 'plugin'), (_) ->

	tpl_login = _.template '''
	<div>
		<span data-role="button" data-icon="forward" data-inline="true" class="login">
			Log in to see account details
		</span>
	</div>
	'''

	tpl_logout = _.template '''
	<div>
		<span data-role="button" data-icon="back" data-inline="true" class="logout">
			Log out. You are currently logged in as <%= username %>
		</span>
	</div>
	'''

	$.fn.login_bar = ->

		@plugin('login_bar')

		# Upon a login click, show the login prompt for the user. 
		.delegate '.login', 'click', ->
			thunk imports('login_window'), ->
				$x = $('#login_window')
				$x.login_window() unless $x.plugin()
				$.mobile.changePage $x
			return false

		# Upon a logout click, delete user session.
		.delegate '.logout', 'click', ->
			thunk imports('eg.eg_api'), (eg) -> eg.openils 'auth.session.delete'
			return false

		# Upon login, show logout link and login status.
		.subscribe 'login_event', (un) ->
			$(@).html(tpl_logout username: un).trigger 'create'
			return false

		# Upon logout, show login link again.
		.subscribe 'logout_event', ->
			$(@).html(tpl_login {}).trigger 'create'
			return false

		# Initially, show login link.
		.html(tpl_login {}).trigger 'create'
