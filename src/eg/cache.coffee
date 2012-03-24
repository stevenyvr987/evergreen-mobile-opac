# Define a caching module

define [
	'eg/eg_api'
	'eg/services'
	'eg/date'
], (eg, services, date) ->

	cacheTO = 60 # seconds
	cache = {}
	queue = {}
	last_cleaned = date.now()

	clean_cache = ->
		current = date.now()
		# Prevent lots of cache requests making it go slow.
		return if (current - last_cleaned) < (20 * 1000)
		last_cleaned = current
		delete(cache[k]) for k, o of cache when (o.timestamp + o.expiry) < current

	key = (method, request) ->
		stringify = (request) ->
			names = []
			a = []
			switch typeof request
				when 'string', 'number', 'boolean'
					a.push String request
				when 'function', 'undefined'
					a.push 'undefined'
				else
					if request is null
						a.push 'null'
					else
						names.push(name) for name of request
						a.push(name, stringify request[name]) for name in names.sort()
			a.join '|'
		method + '|' + stringify request

	(d, method, request) ->
		lookup = services[method]
		action = lookup.action or eg.make_request
		k = key method, request
		entry = cache[k]
		expiry = lookup.cache
		expiry *= cacheTO * 1000

		if (entry?.timestamp + expiry) > date.now()
			next -> d.call entry.data
			return d

		queue[k] = [] if queue[k] is undefined
		queue[k].push(d)
		return d if entry is false # There's already a request in progress for this item.
		cache[k] = false

		req_deferred = new Deferred()
		req_deferred.next (result) ->
			entry =
				timestamp: date.now()
				data: result
			cache[k] = entry
			while queue[k]?.length > 0
				queue[k].pop().call entry.data
			return
		.error (e) ->
			textStatus = e[0]
			while queue[k]?.length > 0
				queue[k].pop().fail textStatus
			delete cache[k]
		action req_deferred, method, request
		clean_cache()
		return d
