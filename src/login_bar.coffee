# login_bar.coffee
#
# Allows the user to log in.
# Informs the user of their username, and allows them to log out.

module 'login_bar', imports('template', 'plugin'), (_) ->

	tpl_login = _.template '''
	<span class="link login">Log in</span>
	<span>to see account details</span>
	'''

	tpl_logout = _.template '''
	<span class="link logout">Log out</span>
	<span>Currently logged in as</span>
	<span class="username"><%= username %></span>
	'''

	$.fn.login_bar = ->

		@plugin('login_bar')

		# Initially show login link.
		.html(tpl_login {})

		# Upon a login click, show the login prompt for the user. 
		.delegate '.login', 'click', ->
			thunk imports('login_window'), -> $('#login_window').login_window().refresh()
			return false

		# Upon a logout click, delete user session.
		.delegate '.logout', 'click', ->
			thunk imports('eg.eg_api'), (eg) -> eg.openils 'auth.session.delete'
			return false

		# Upon login, show logout link and status message.
		.subscribe 'login_event', (un) ->
			x = tpl_logout { username: un }
			$(@).html x
			return false

		# Upon logout, show login link again.
		.subscribe 'logout_event', ->
			$(@).html tpl_login {}
			return false
