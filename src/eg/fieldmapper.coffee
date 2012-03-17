# We define a module to provide services to resolve 
# inconsistencies between the server and client
# in how they represent values of a gvein data type
# and how they structure certain data objects.
#
# For example, the non-Javascript server will represent a number as 1 or '1'
# whereas the Javascript client will represent it as the *Number* object.
#
# Moreover, the server will represent a data object
# as values in an array, with the position of a value in the array corresponding to the field,
# whereas the client will need to represent the values in an object with the field names.
# When we convert an array into an object, it is known as 'fieldmapping'
# and will be accomplished by the *fieldmap* function.
# The converse operation is accomplished by the *mapfield* function.

# The module is dependent on Javascript files that are not packaged as modules.
# *fmall* will supply a global object *fmclasses* that defines
# a mapping between position indices and field names.
# *fm_datatypes* will supply another global object that maps between fields and data types.
define ['fmall', 'fmd'], ->

	# Define an export object to reference the exported functions.
	expo = {}

	# ***
	# Define a helper function to guard a given function
	# from being applied against a null argument.
	guard_null = (fn) -> (x) -> if x? then fn.apply @, arguments else x

	# Define a helper function to guard a given function
	# from being applied against an argument that is an *ilsevent* object.
	guard_ilsevent = (fn) ->
		guard_null (x) ->
			if typeof x is 'object' and (x.ilsevent isnt undefined or (x[0] and x[0].ilsevent isnt undefined))
				return x
			else
				return fn.apply @, arguments

	# Define a public object to cast data types.
	expo.ret_types =

		# We type cast a given input as a number or string
		# except if it is a null value.
		'number': guard_ilsevent Number
		'string': guard_ilsevent String

		# We type cast the number values in a given *search* object
		# except if it is an *ilsevent* object.
		'search': guard_ilsevent (x) ->
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

		# We type cast the number values in a given *prefs* object
		# except if it is an *ilsevent* object.
		'prefs': guard_ilsevent (x) ->
			(x[p] = Number x[p]) for p in [
				'opac.hits_per_page'
				'opac.default_search_location'
				'opac.default_search_depth'
			] when x[p]
			return x

	# ***
	# Define a public function to 'flatten' a given tree of objects.
	# *opac_visible* objects are returned in a list.
	# > FIXME: this could be integrated into *ret_types()* as another type cast operation,
	expo.flatten_tree = (o) ->

		_flatten_tree = (os) ->
			a = []
			$.each os, (n, o) ->
				return [] unless o.opac_visible
				a.push o
				(a.push v) for k, v of _flatten_tree o.children if o.children
				delete o.children
			return a

		# We need to deep-copy the object,
		# otherwise the version in the cache will be modified.
		_flatten_tree $.extend true, {}, [o]



	# ***
	# We define a helper object for use by the public *fieldmap* function
	# to cast data types for client use.
	# We have to guard against casting only null values.
	expo.typemap =
		'':        (x) -> x
		'fm':      guard_null (x) => if typeof x is 'object' then expo.fieldmap x else x
		'number':  guard_null Number
		'string':  guard_null String

		# > We will use Date objects to represent dates in the client.
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


	# ***
	# Define a function to convert a class hint
	# and an array of property values into an object.
	# The function uses *fmclasses*,
	# a mapping between position indices and field names.
	# If we find an empty array or object, we will simply return it.
	_fieldmap = (c, p) ->
		o = {}
		if (ts = fm_datatypes[c])?
			for name, n in fmclasses[c]
				o[name] = if t = ts[name] then expo.typemap[t] p[n] else p[n]
		else
			for name, n in fmclasses[c]
				o[name] = p[n]
		return o

	# Define the public version of *_fieldmap()*.
	# It will handle the case in which the input array could be inside an array,
	# The conversion is shown by the following ASCII diagrams.
	#
	# 	x                 =  { '__c': classhint, '__p': [    1,     2,     3 ] }
	# 	fmclasses         =  {        classhint:        ['a',   'b',   'c'   ] }
	# 	y = fieldmap(x)  //  {                           'a':1, 'b':2, 'c':3   }
	#
	# 	xs                = [{ '__c': classhint, '__p': [    1,     2,     3 ] }]
	# 	fmclasses         =  {        classhint:        ['a',   'b',   'c'   ] }
	# 	ys = fieldmap(x) // [{                           'a':1, 'b':2, 'c':3   }]
	#
	expo.fieldmap = (x) ->
		if $.isArray x
			return x unless x.length
			_fieldmap(a.__c, a.__p) for a in x when a.__c
		else
			if x.__c then _fieldmap(x.__c, x.__p) else {}


	# ***
	# We define the converse of *typemap*,
	# a helper object for use by *mapfield()*
	# to cast data types for server use.
	# We have to guard against only null types.
	expo.maptype =
		'':        (x) -> x
		'fm':      guard_null (x, cls) => if typeof x is 'object' then expo.mapfield { cls:x } else x
		'number':  guard_null Number
		'string':  guard_null String
		'date':    (x) -> x
		'boolean': (x) -> if x then 't' else 'f'

	# The reverse operation of *fieldmap()*,
	# ie, convert a given object to an array of values.
	# The function uses *fmclasses*, a mapping between position indices and field names.
	# The conversion is shown by the following ASCII diagram.
	#
	# 	xs                 = [{        classhint:        {'a':1, 'b':2, 'c':3 } }]
	# 	fmclasses          =  {        classhint:        ['a',   'b',   'c'   ] }
	# 	ys = mapfield(xs) // [{ '__c': classhint, '__p': [    1,     2,     3 ] }]
	#
	expo.mapfield = (xs) ->
		p = []
		for c, o of xs
			class_hint = c
			if (ts = fm_datatypes[c])?
				for name, n in fmclasses[c]
					p[n] = if t = ts[name] then expo.maptype[t] o[name], c else o[name]
			else
				for name, n in fmclasses[c]
					p[n] = o[name]
		__c: class_hint, __p: p

	return expo
