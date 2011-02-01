# fieldmapper.coffee
#
# Field mapping functions:
#
# These turn the raw data returned by the server into objects which are easily
# manipulated, and back again.

# Synchronously load dependents that are not jModules.
#jMod.include('eg.fmall_1_6', 'eg.fm_datatypes')
jMod.include 'dojo.fieldmapper.fmall', 'eg.fm_datatypes'

module 'eg.fieldmapper', ->
	that = @

	identity = (x) -> x

	# Sometimes a value in a fieldmapped object is null. If so, we don't
	# want to cast it, because we don't want a value of, e.g., "null"
	guard_null = (fn) -> (x) -> if x? then fn.apply @, arguments else x

	# We don't want to try to cast an error object
	guard_ret = (fn) ->

		guard_null (x) ->
			if typeof x is 'object' and (x.ilsevent isnt undefined or (x[0] and x[0].ilsevent isnt undefined))
				return x
			else
				return fn.apply @, arguments

	@ret_types = {
		'number': guard_ret Number
		'string': guard_ret String
		'search': guard_ret (x) ->
			(x[f] = Number x[f]) for f in [
				'count'
				'superpage_size'
			] when x[f] isnt undefined
			(x.ids[n] = Number id) for id, n in x.ids
			if x.superpage_summary isnt undefined
				(x.superpage_summary[f] = Number x.superpage_summary[f]) for f in [
					'checked'
					'visible'
					'estimated_hit_count'
					'excluded'
					'deleted'
					'total'
				] when x.superpage_summary[f] isnt undefined
			return x
		'prefs': guard_ret (x) ->
			(x[p] = Number x[p]) for p in [
				'opac.hits_per_page'
				'opac.default_search_location'
				'opac.default_search_depth'
			] when x[p]
			return x
	}


	typemap = {
		'':        identity
		'fm':      guard_null (x) => if typeof x is 'object' then @fieldmap x else x
		'number':  guard_null Number
		'string':  guard_null String

		# Use Date objects to represent dates in the app.
		# For the most part though,
		# dates are displayed to the user as strings,
		# and possibly modified by the user as strings
		# and then sent back to the server as strings.
		'date': (x) ->
			return x unless x?
			[yr, mon, day, hh, mm, ss, tz] = ((String x).replace /\D/g, ' ').split ' '
			new Date yr, --mon, day, hh, mm, ss

		'boolean': (x) ->
			switch x
				when 't', '1' then true
				when 'f', '0' then false
				else !!x
	}


	# Map an array of values to an object using a map between position indices and field names.
	# If we find an empty array or object, we will return it.
	# The mapping is shown by the following ASCII diagram.
	#	x                 =  { '__c': mapname, '__p': [    1,     2,     3 ] }
	#	fmclasses         =  {        mapname:        ['a',   'b',   'c'   ] }
	#	y = fieldmap(x)   #  {                         'a':1, 'b':2, 'c':3   }
	#
	# The input could be an array, in which the diagram would be modified as follows.
	#	xs                = [{ '__c': mapname, '__p': [    1,     2,     3 ] }]
	#	fmclasses         =  {        mapname:        ['a',   'b',   'c'   ] }
	#	ys = fieldmap(x)  # [{                         'a':1, 'b':2, 'c':3   }]
	@fieldmap = (x) ->

		_fieldmap = (m, a) ->
			o = {}
			if (ts = fm_datatypes[m])?
				for name, n in fmclasses[m]
					o[name] = if t = ts[name] then typemap[t] a[n] else a[n]
			else
				for name, n in fmclasses[m]
					o[name] = a[n]
			return o

		if $.isArray x
			return x unless x.length
			_fieldmap(a.__c, a.__p) for a in x when a.__c
		else
			if x.__c then _fieldmap(x.__c, x.__p) else {}



	maptype = {
		'':        identity
		'fm':      guard_null (x, cls) => if typeof x is 'object' then @mapfield { cls:x } else x
		'number':  guard_null Number
		'string':  guard_null String
		'date':    identity
		'boolean': (x) -> if x then 't' else 'f'
	}

	# The reverse operation of fieldmap(),
	# Map to an array of values from an object using a map between position indices and field names.
	#	xs                 = [{        mapname:        {'a':1, 'b':2, 'c':3 } }]
	#	fmclasses          =  {        mapname:        ['a',   'b',   'c'   ] }
	#	ys = mapfield(xs)  # [{ '__c': mapname, '__p': [    1,     2,     3 ] }]
	@mapfield = (xs) ->

		a = []
		for m, o of xs
			map = m
			if (ts = fm_datatypes[m])?
				for name, n in fmclasses[m]
					a[n] = if t = ts[name] then maptype[t] o[name], m else o[name]
			else
				for name, n in fmclasses[m]
					a[n] = o[name]

		{ '__c': map, '__p': a }


	# Input fm.flatten_tree( array, [flag] )
	#	fm.flatten_tree( array ) : return the visible children in the tree
	#	fm.flatten_tree( array, flag ): return the complete tree
	@flatten_tree = (o) ->

		_flatten_tree = (os) ->
			a = []
			$.each os, (n, o) ->
				return [] unless o.opac_visible
				a.push o
				(a.push v) for k, v of _flatten_tree o.children if o.children
				delete o.children
			return a

		# We need to deep copy the object
		# otherwise the version in the cache will be modified.
		_flatten_tree $.extend true, {}, [o]

	return @
