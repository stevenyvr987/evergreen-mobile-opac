# Dictionary of ajax calls keyed by name of Evergreen service method

define [
	'jquery'
	'eg/fieldmapper'
	'eg/date'
	'eg/services'
	'eg/cache'
	'eg/auth'
	'exports'
], ($, fm, date, services, cache, auth, eg) ->

	ajaxOptions =
		url: '/osrf-gateway-v1'
		type: 'post'
		dataType: 'json' # response data is JSON formatted unless overidden
		timeout: 60 * 1000
		global: true

	$.ajaxSetup ajaxOptions

	# Serialize an array of form elements or a set of
	# key/values into a query string
	# From jQuery. Released under either the MIT or GPL license
	urlencode = (a) ->
		s = []
		add = (key, value) -> s[s.length] = encodeURIComponent(key) + '=' + encodeURIComponent(value)

		# assume that it's an object of key/value pairs
		# Serialize the key/values
		$.each a, (j, val) ->
			# If the value is an array then the key names need to be repeated
			if $.isArray val
				$.each val, (n, v) -> add j, v
			else
				add j, if $.isFunction(val) then val() else val

		s.join "&" # Return the resulting serialization

	# Possible invocations:
	# openils('service_name', request, function (response) {})
	# openils('service_name', function (response) {})
	# openils()
	openils = (method, request, success) ->

		# if 1st argument does not correspond to a service name,
		# then return a list of service names for introspection
		lookup = services[method]
		if lookup is undefined
			names = []
			names.push(n) for n in services when n
			return names

		d = new Deferred()

		# if 2nd argument refers to a function,
		# then it must be the success callback and param is a null value
		if typeof request is 'function'
			success = request
			request = null

		if typeof success is 'function'
			d = d.next success

		# Make the service request. The result is either already cached, via
		# the looked up action, or via the default action.
		action = if lookup.cache and not lookup.login_required then cache else (lookup.action or default_action)
		action method, request, d
		return d

	default_action = (method, request, d) ->

		lookup = services[method]

		# If the call requires the user to be logged in, and the user isn't,
		# trigger the login window.
		if lookup.login_required
			unless auth.session.id and auth.session.timeout > date.now()
				$().publish 'session.required', [new Deferred().next -> default_action method, request, d]
				return

		# preprocess input parameters and convert to JSON format
		# lookup version of param is an array
		request = if typeof lookup.i is 'function' then lookup.i(request) else []
		request = $.map request, (v) -> JSON.stringify v

		$.ajax {
			data: urlencode {
				service: "open-ils.#{method.split('.', 1)[0]}"
				method: "open-ils.#{method}"
				param: request
			}
			success: (data) ->

				# Announce any debug message
				$().publish 'prompt', ['Debug', data.debug] if data.debug

				# Announce any abnormal ilsEvent message
				#ilsevent = data.payload?[0]?.ilsevent?
				#if ilsevent isnt 0 and ilsevent isnt '0'
				if data.payload
				  if data.payload[0]
				    if typeof data.payload[0] is 'object'
				      if data.payload[0].ilsevent isnt undefined
				        if data.payload[0].ilsevent isnt 0
				          if data.payload[0].ilsevent isnt "0"

						  	# FIXME This is a hack to easily prevent EG 1.6 from
							# displaying a server error when there is a permission problem (#5000)
							# for showing holds list.
							# This should be removed in a more finalized version.
				            if data.payload[0].ilsevent isnt "5000"
				              $().publish 'prompt', ['Server error', data.payload[0]]

							# We leave it up to the service callback to handle
							# abnormal ILS events.
				            d.call data.payload[0]
				            auth.reset_timeout()
				            return

				# data.payload.length could be zero
				cb_data = {}
				try
					cb_data = if lookup.o then lookup.o data else data.payload[0]
					cb_data = fm.ret_types[lookup.type](cb_data) if lookup.type
				catch e
					console.log e if e.type
					$().publish 'prompt', ['Client error', e.debug] if e.status and e.status isnt 200
					cb_data = e
				finally
					# FIXME: after all of the above calculation, cb_data could be an ilsevent object.
					d.call cb_data
					auth.reset_timeout()
					return

			# Handle local ajax errors:
			# Normally, jQuery will promote a local error to a global error
			# and will trigger all DOM elements for a global ajax error.
			# Instead, we have turned off global events
			# and we will trigger an element class to show local ajax errors.
			error: (xhr, textStatus, errorThrown) ->
				x = xhr.responseText

				# If response text is undefined,
				# it likely means xhr was aborted by the user.
				unless x?
					# Is there a debug message buried within JSON text?
					# Also, we fix a JSON format error (missing double quote).
					try
						x = JSON.parse(x.replace(
							 ',"status'
							'","status'
						)).debug
					catch e
						throw e if e.message isnt 'JSON.parse'

				# textStatus is a simple text version of the error number
				# x is a more substantial text message
				# Not quite sure what errorThrown is about.
				d.fail [textStatus, x, errorThrown]
				$().publish 'prompt', ['Network error', x]
		}

	# ### Define a jQuery method of _openils()_
	# Use the method to make service calls in the context of jQuery objects.
	# While waiting for the server response, the method will show a loading message to the user.
	# If the server responds, the method will call the service callback with the response.
	# Otherwise, the method will show a failed message to the user.
	$.fn.openils = (usage, svc) ->

		# Define the service callback,
		# which is specified in the 3rd or 4th position of the argument list.
		cb = ->

		# Define a helper to determine whether to call cb() or failed().
		succeeded_or_failed = (res) =>
			# >FIXME: we ought to fix eg.api so that the ilsevent object need not be used here.
			if res.ilsevent? or res instanceof Error
				@failed usage
			else
				cb.call @succeeded(), res

		@loading usage
		switch arguments.length
			when 4
				cb = arguments[3]
				d = openils svc, arguments[2], succeeded_or_failed
			when 3
				cb = arguments[2]
				d = openils svc, succeeded_or_failed
			else
				# We catch a possible coding error in the OPAC:
				# there should be at least three entries in the argument list.
				return @failed(usage).publish 'prompt', ['Client error', "Malformed service method #{svc}"]
		# We catch another possible coding error in the OPAC:
		# openils() normally returns a deferred object, not an array.
		@failed(usage).publish 'prompt', ['Client error', "Undefined service method #{svc}"] if $.isArray d
		return @


	$.extend true, eg,
		ajaxOptions: ajaxOptions
		default_action: default_action
		openils: openils
	return
