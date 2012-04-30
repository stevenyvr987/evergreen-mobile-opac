# Define a module to persist authentication session parameters,
# including the user object provided by a service call to auth.session.retrieve

define [
	'jquery'
	'eg/eg_api'
	'eg/date'
], ($, eg, date) ->

	sessionTO = 60 # seconds
	auth = {}
	no_session =
		session:
			cryptkey: null
			id: null
			time: null
			user: {}
	$.extend true, auth, no_session
	auth.no_session = no_session

	timeouts = []
	auth.setup_timeout = (authtime) ->
		clicked_in_time = false

		$.each timeouts, -> @cancel()
		timeouts = []
		return if authtime <= 0

		timeouts.push wait(authtime).next ->
			unless clicked_in_time
				eg.openils 'auth.session.delete'
				$().publish 'session.timeout'

		timeouts.push wait(authtime - sessionTO).next ->
			relogin = ->
				if auth.logged_in()
					clicked_in_time = true
					eg.openils 'auth.session.retrieve'
				return false
			$().publish 'prompt', ['Your login session', 'will timeout in 1 minute unless there is activity.', sessionTO * 1000, relogin]

	auth.reset_timeout = ->
		s = auth.session
		if s.id and s.timeout > date.now()
			s.timeout = date.now() + (s.time * 1000)
			auth.setup_timeout s.time

	# Check if the user is logged in. If their session has expired but we
	# still have login state lying around, force a logout.
	auth.logged_in = ->
		s = auth.session
		if s.id
			if s.timeout > date.now()
				return s.id
			eg.openils 'auth.session.delete'
		return false

	return auth
