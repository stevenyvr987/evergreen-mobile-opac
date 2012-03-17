# Dictionary of ajax calls keyed by name of Evergreen service method
#
# To do:
# User session cookie
# Exception handling
# Extend jQ with an eg object? For example, $.eg.session, $.eg.search, $.eg.openils()
# Define i/o using functional compositions
# Define object methods for user session

define [
	'jquery'
	'js/lib/md5.js'
	'eg/fieldmapper'
	'eg/date'
], ($, md5, fm, date) ->

	#attempted_username = 0
	no_session = 0
	timeouts = []

	urlencode = ->
	openils = ->
	auth = ->
	make_request = ->
	cache = ->
	setup_timeout = ->
	reset_timeout = ->
	logged_in = ->

	ajaxOptions = {
		# reverse-proxied to production
		url: '/osrf-gateway-v1'
		# reverse-proxied to coconut
		#url: '/osrf-gateway-v1-2'
		# reverse-proxied to devcatalog.kcls.org
		#url: '/osrf-gateway-v1-3'
		# reverse-proxied to catalog.kcls.org
		#url: '/osrf-gateway-v1-4'
		type: 'post'
		dataType: 'json' # response data is JSON formatted unless overidden
		timeout: 60 * 1000
		#global: false # turn off all global ajax events
		global: true
	}

	$.ajaxSetup ajaxOptions

	# common I/O signatures for eg_services
	i0 = -> [auth.session.id]
	i1 = (id) -> [id]
	i2 = (id) -> [auth.session.id, id]
	i3 = (id) -> [auth.session.id, id or auth.session.user.id]
	s1 = (o) -> [o.search]
	o1 = (x) -> x.payload[0]
	#o2 = (x) -> fm.fieldmap x.payload
	o3 = (x) -> fm.fieldmap o1 x
	a2o = (xs) ->
		o = {}
		(o[x.id] = x) for x in xs
		return o
	o4 = (x) -> a2o o3 x
	o6 = (x) -> fm.flatten_tree o3 x
	o5 = (x) -> a2o o6 x


	# Registry of Evergreen or openils services
	eg_services = {
		'actor.container.create': {
			i: (x) ->
				cbreb = {
						items: null
						btype: 'bookbag'
						id: null
						name: ''
						owner: auth.session.user.id
						pub: false
					}
				[auth.session.id, 'biblio', fm.mapfield { cbreb: $.extend cbreb, x }]
			o: o1
			type: 'number'
			login_required: true
		}
		'actor.container.full_delete': {
			i: (id) -> [auth.session.id, 'biblio', id]
			o: o1
			type: 'number'
			login_required: true
		}
		'actor.container.retrieve_by_class': {
			i: (id) -> [auth.session.id, id or auth.session.user.id, 'biblio', 'bookbag']
			o: o3
			login_required: true
		}
		'actor.container.flesh': {
			i: (bucket_id) -> [auth.session.id, 'biblio', bucket_id]
			o: o3
			login_required: true
		}
		'actor.container.item.create': {
			i: (item) -> [auth.session.id, 'biblio', fm.mapfield {cbrebi:item}]
			o: o1
			type: 'number'
			login_required: true
		}
		'actor.container.item.delete': {
			i: (id) -> [auth.session.id, 'biblio', id]
			o: o1
			type: 'number'
			login_required: true
		}
		'actor.container.update': {
			i: (cbreb) -> [auth.session.id, 'biblio', fm.mapfield {cbreb:cbreb}]
			o: o1
			type: 'number'
			login_required: true
		}
		'actor.org_types.retrieve': {
			o: o4
			login_required: false
			cache: 24 * 60
		}
		# Gets all opac_visible ou nodes.
		'actor.org_tree.retrieve': {
			o: o5
			login_required: false
			cache: 24 * 60
		}
		'actor.org_tree.descendants.retrieve': {
			i: (id) -> [id or 1]
			o: o6
			login_required: false
			cache: 24 * 60
		}
		'actor.patron.settings.retrieve': {
			i: i3
			o: (data) ->
				auth.session.settings = data.payload[0]
				auth.session.settings
			type: 'prefs'
			login_required: true
		}
		'actor.patron.settings.update': {
			i: (obj) -> [auth.session.id, auth.session.user.id, obj]
			type: 'number'
			login_required: true
		}
		'actor.note.retrieve.all': {
			i: (id) -> [auth.session.id, { patronid: id or auth.session.user.id, pub: 1 }]
			login_required: true
		}
		'actor.ou_setting.ancestor_default': {
			i: (request) -> [1, request] # [org_id, request]
			o: o1
		}
		'actor.user.checked_out': {
			i: i3
			login_required: true
		}
		'actor.user.checked_out.authoritative': {
			i: i3
			login_required: true
		}
		'actor.user.checked_out.count': {
			i: i3
			login_required: true
			# Ensure that response has a zero total property.
			o: (data) ->
				o = o1 data
				o.total = 0 unless o.total?
				o
		}
		'actor.user.checked_out.count.authoritative': {
			i: i3
			login_required: true
			o: (data) ->
				o = o1 data
				o.total = 0 unless o.total?
				o
		}
		'actor.user.email.update': {
			i: i2
			type: 'number'
			login_required: true
		}
		'actor.user.password.update': {
			i: (pw) -> [auth.session.id, pw.new_password, pw.old_password]
			type: 'number'
			login_required: true
		}
		'actor.user.username.update': {
			i: i2
			type: 'number'
			login_required: true
		}
		'actor.user.fleshed.retrieve': {
			i: i3
			o: o3
			login_required: true
		}
		'actor.user.fleshed.retrieve_by_barcode': {
			i: i2
			o: o3
			login_required: true
		}
		'actor.user.fines.summary': {
			i: i3
			o: o3
			login_required: true
		}
		'actor.user.fines.summary.authoritative': {
			i: i3
			o: o3
			login_required: true
		}
		'actor.user.transactions.have_charge.fleshed': {
			i: i3
			o: (data) -> fm.fieldmap $.map data.payload[0], (x) -> x.transaction
			login_required: true
		}
		'actor.username.exists': {
			i: i2
			type: 'number'
			login_required: true
		}

		# input, username; output, encryption key
		'auth.authenticate.init': {
			i: i1
			o: (data) -> auth.session.cryptkey = o1 data
			login_required: false
		}
		# input, {username: un, password: pw, type: 'staff', org: ou_id}
		# output, {authtoken: sessionID, authtime: sessiontime}
		'auth.authenticate.complete': {
			i: (o) ->
				#attempted_username = o.username
				o.password = hex_md5 auth.session.cryptkey + hex_md5 o.password
				[o]
			o: (data) ->
				response = data.payload[0]

				if data.status isnt undefined and data.status isnt 200
					auth.session.id = 0
					#attempted_username = ''
					throw data
				if response.ilsevent isnt undefined and response.ilsevent isnt 0
					auth.session.id = 0
					#attempted_username = ''
					throw response

				response = response.payload; # there is an inner payload!
				auth.session.id = response.authtoken
				auth.session.time = response.authtime
				auth.session.timeout = date.now() + (response.authtime * 1000)

				$.ajaxSetup $.extend {}, ajaxOptions, {
					beforeSend: (xhr) -> xhr.setRequestHeader 'X-OILS-Authtoken', auth.session.id
				}

				setup_timeout response.authtime
				#$().publish 'login_event', [attempted_username]
				#attempted_username = ''
				return response
			login_required: false
		}
		# Combine authenticate.init and authenticate.complete
		'auth.session.create': {
			action: (d, method, o) ->
				# FIXME: the following two openils requests can be done in parallel.
				openils('auth.authenticate.init', o.username)
				.next ->
					openils 'actor.ou_setting.ancestor_default', 'opac.barcode_regex'
				.next (x) ->
						# If username is a barcode then convert username property to barcode property.
						# Barcode is determined by a regex defined by local sys admin
						# or by usernames beginning with a number.
						barcode = new RegExp if x?.value then "^#{x.value}$" else '^\\d+'
						if o.username.match barcode
							o.barcode = o.username
							delete o.username
				.next ->
					openils 'auth.authenticate.complete', o
				.next (data) -> d.call data
		}
		# input, sessionid; output, sessionid
		'auth.session.delete': {
			i: i0
			o: (data) ->
				$.extend true, auth, no_session
				$.ajaxSetup ajaxOptions
				$().publish 'logout_event'
				setup_timeout 0
				data.payload[0]
			login_required: false # Logging out multiple times is OK
		}
		'auth.session.retrieve': {
			i: i0
			o: (data) -> auth.session.user = o3 data
			login_required: true
		}

		# input, hostname and client version ID; output, HTML page
		'auth.authenticate.confirm_the_server': {
			action: (d, method, obj) ->
				$.ajax {
					url: "/xul/rel_#{obj.client}/server"
					type: 'get'
					dataType: 'html'
					success: (data) -> d.call data
				}
		}

		'circ.open_non_cataloged_circulation.user': { i: i3 }
		'circ.holds.id_list.retrieve.authoritative': {
			i: i3
			o: o1
			login_required: true
		}
		'circ.holds.retrieve': {
			i: i3
			o: o3
			login_required: true
		}
		'circ.hold.details.retrieve.authoritative': {
			i: i2
			o: (o) ->
				o = o1 o
				o.mvr = fm.fieldmap o.mvr
				o.hold = fm.fieldmap o.hold
				o.status = switch Number o.status
					when 1 then 'Waiting for copy to become available'
					when 2 then 'Waiting for copy capture'
					when 3 then 'In transit'
					when 4 then 'Ready for Pickup'
					else 'Error'
				o
			login_required: true
		}
		'circ.hold.queue_stats.retrieve': {
			i: i2
			o: (o) ->
				o = o1 o
				o.status = switch Number o.status
					when 1 then 'Waiting for copy to become available'
					when 2 then 'Waiting for copy capture'
					when 3 then 'In transit'
					when 4 then 'Ready for Pickup'
					else 'Error'
				o
			login_required: true
		}
		'circ.hold.status.retrieve': {
			i: i2
			o: (data) ->
				switch Number data.payload[0]
					when 1 then [1, 'Waiting for copy to become available']
					when 2 then [2, 'Waiting for copy capture']
					when 3 then [3, 'In transit']
					when 4 then [4, 'Ready for Pickup']
					else ['-1', 'Error']
			login_required: true
		}
		'circ.holds.create': {
			i: (ahr) ->
				a = $.extend {
					requestor: auth.session.user.id
					usr: auth.session.user.id
					hold_type: 'T'
				}, ahr
				[auth.session.id, fm.mapfield {ahr:a}]
			o: o1
			type: 'number'
			login_required: true
		}
		'circ.hold.update': {
			i: (ahr) -> [auth.session.id, fm.mapfield {ahr:ahr}]
			o: o1
			type: 'number'
			login_required: true
		}
		'circ.hold.cancel': {
			i: i2
			o: o1
			type: 'number'
			login_required: true
		}
		'circ.title_hold.is_possible': {
			i: (x) ->
				obj = {
					titleid: 0
					hold_type: 'T'
					patronid: auth.session.user.id
					depth: 0
					pickup_lib: 1
				}
				$.extend obj, x # input x does not need to extend hold_type nor patronid
				[auth.session.id, obj]
			o: o1
			login_required: true
		}

		'circ.money.billing.retrieve.all': {
			i: i2
			o: o3
			login_required: true
		}
		'circ.retrieve': {
			i: i2
			o: o3
			login_required: true
		}
		'circ.retrieve.authoritative': {
			i: i2
			o: o3
			login_required: true
		}
		'circ.renew': {
			i: (copy) ->
				[auth.session.id, {
					patron: auth.session.user.id
					copyid: copy
					opac_renewal: 1
				}]
			o: (result) ->
				result = result.payload[0]
				if result.textcode is 'SUCCESS'
					result = result.payload
					result.circ = fm.fieldmap result.circ
					result.copy = fm.fieldmap result.copy
					result.record = fm.fieldmap result.record
				result
			login_required: true
		}

		'ingest.full.biblio.record.readonly': { i: i1 }

		'search.asset.call_number.retrieve': {
			i: i1
			o: o3
			login_required: false
			cache: 5
		}
		'search.asset.copy.retrieve': {
			i: i1
			o: o3
			login_required: false
			cache: 5
		}
		'search.asset.copy.retrieve_by_cn_label': {
			i: (o) -> [o.id, o.cn, o.org_id]
			login_required: false
			cache: 5
		}
		'search.asset.copy.fleshed2.find_by_barcode': {
			i: i1
			o: o3
			login_required: false
			cache: 5
		}
		'search.asset.copy.fleshed2.retrieve': {
			i: i1
			o: o3
			login_required: false
			cache: 5
		}
		'search.authority.crossref.batch': {
			i: (obj, callback) ->
				input = []
				$.each obj, (type, obj2) ->
					$.each obj2, (n) ->
						input.push [type, n]
				[input]
			login_required: false
			cache: 5
		}
		'search.bib_id.by_barcode': {
			i: i1
			type: 'number'
			login_required: false
			cache: 5
		}
		'search.biblio.bib_level_map.retrieve.all': {
			o: o3
			login_required: false
			cache: 24 * 60
		}
		'search.biblio.lit_form_map.retrieve.all': {
			o: o3
			login_required: false
			cache: 24 * 60
		}
		'search.biblio.item_form_map.retrieve.all': {
			o: o3
			login_required: false
			cache: 24 * 60
		}
		'search.biblio.item_type_map.retrieve.all': {
			o: o3
			login_required: false
			cache: 24 * 60
		}
		'search.biblio.audience_map.retrieve.all': {
			o: o3
			login_required: false
			cache: 24 * 60
		}
		'search.biblio.isbn': {
			i: s1
			type: 'search'
			login_required: false,
			cache: 5
		}
		'search.biblio.issn': {
			i: s1
			type: 'search'
			login_required: false
			cache: 5
		}
		'search.biblio.marc': {
			i: (search) ->
				[
					{
						"searches": search.search
						"limit": 200
						"org_unit": search.org_unit or 1
						"depth": search.depth or 0
						"sort": search.sort
						"sort_dir": search.sort_dir
					}
					search.limit
					search.offset
				]
			type: 'search'
			login_required: false
			cache: 5
		}
		'search.biblio.mods_from_copy': {
			i: i1
			o: o3
			login_required: false
			cache: 5
		}
		'search.biblio.tcn': {
			i: s1
			type: 'search'
			login_required: false
			cache: 5
		}
		'search.biblio.multiclass.query': {
			i: (o) ->
				o.available = Number o.available if o.available

				# Calculate item type, eg, 'at' becomes ['a', 't']
				# FIXME needs to be recoded in a nicer way
				if o.item_type
					if $.isArray o.item_type
						o.item_type = $.map o.item_type, (x) -> x # flatten
						(o.item_type[n] = v.split '' if v) for v, n in o.item_type
					else
						o.item_type = o.item_type.split '' if o.item_type
					o.item_type = $.map o.item_type, (x) -> x # flatten

				# Calculate publication date
				if o.year_begin
					switch x = o.pub_year_verb
						when 'between' then o['between'] = [o.year_begin, o.year_end]
						when 'is'      then o['between'] = [o.year_begin, o.year_begin]
						else                o[x]         =  o.year_begin

				# Calculate search phrase.
				#
				spaces = /\ +/
				# Force singletons to lists.
				(o[x] = [o[x]]) for x in ['term', 'search_term_verb', 'default_class'] when not $.isArray o[x]
				# For each search term...
				x = for v, n in o.term when v
					# Trim and remove duplicate white space.
					v = (av = ($.trim v).split spaces).join ' '
					# Add search verb indicator.
					v = switch o.search_term_verb[n]
						when '=' then "\"#{v}\"" # 'matches exactly'
						when '-' then (('-' + vv) for vv in av).join ' ' # 'does not contain'
						else v # default is 'contains'
					# Add search class prefix.
					"#{o.default_class[n]}:#{v}"
				# Join all search terms into search phrase.
				term = x.join ' '

				# Calculate sort filter.
				if o.sort
					switch o.sort
						when 'pubdate asc'
							o.sort = 'pubdate'
							o.sort_dir = 'asc'
						when 'pubdate desc'
							o.sort = 'pubdate'
							o.sort_dir = 'desc'
						when 'title asc'
							o.sort = 'title'
							o.sort_dir = 'asc'
						when 'title desc'
							o.sort = 'title'
							o.sort_dir = 'desc'
						when 'author asc'
							o.sort = 'author'
							o.sort_dir = 'asc'
						when 'author desc'
							o.sort = 'author'
							o.sort_dir = 'desc'
						else
							o.sort = ''

				# Delete properties that do not belong in a bona fide search object.
				delete o[x] for x in [
					'default_class'
					'pub_year_verb'
					'search_term_verb'
					'term'
					'type'
					'year_begin'
					'year_end'
				]
				[o, term, 1]
			o: (data) ->
				x = data.payload[0]
				# flatten the list of ids
				x.ids = $.map x.ids, (v) -> v
				return x
			type: 'search'
			login_required: false
			cache: 5
		}
		'search.biblio.record_entry.slim.retrieve': {
			i: i1
			o: o3
			login_required: false
			cache: 5
		}
		'search.biblio.record.mods_slim.retrieve': {
			i: i1
			o: o3
			login_required: false
			cache: 5
		}
		'search.biblio.metarecord.mods_slim.retrieve': {
			i: i1
			o: o3
			login_required: false
			cache: 5
		}
		'search.biblio.record.copy_count': {
			i: (o) -> [o.location, o.id]
			o: (data) ->
				x = data.payload[0]
				y = {}
				$.each x, (i, xi) ->
					y[i] = {
						available: xi.available
						count: xi.count
						depth: xi.depth
						org_unit: xi.org_unit
					}
				return y
			login_required: false
			cache: 5
		}
		'search.biblio.record.html': {
			i: i1
			login_required: false
			cache: 5
		}
		'search.biblio.copy_counts.summary.retrieve': {
			i: i1
			o: (data) ->
				data = data.payload[0]
				# [ [org_id, callnumber_label, {status1=>count1, status2=>count2}], ]
				# [ {org_id=>{callnumber_label=>{status1=>count1, status2=>count2}}}, ]
				# where statusn is asset.copy.status which is an FK to config.copy_status
				# and copy_status is opac_visible
				$.each data, (n) ->
					data[n] = {
						org_id: Number @[0]
						callnumber: @[1]
						available: @[2]
					}
				return data
			login_required: false
			cache: 5
		}
		'search.biblio.copy_location_counts.summary.retrieve': {
			i: (o) -> [o.id, o.org_id, o.depth]
			o: (data) ->
				data = data.payload[0]
				# [ [org_id, callnumber_label, copy_location, {status1=>count1, status2=>count2}], ]
				$.each data, (n) ->
					data[n] = {
						org_id: Number @[0]
						callnumber: @[1]
						copylocation: @[2]
						available: @[3]
					}
				return data
			login_required: false
			cache: 5
		}
		'search.callnumber.retrieve': {
			i: i1
			o: o3
			login_required: false
			cache: 5
		}
		'search.callnumber.browse': {
			i: (o) -> [o.callnumber or '', o.org_id or 1, o.size or 9, o.offset or 0]
			o: (data) ->
				$.each data.payload[0], (n, data) ->
					data.cn = fm.fieldmap(data.cn)
					data.mods = fm.fieldmap(data.mods)
				data.payload[0]
			login_required: false
			cache: 5
		}
		'search.config.copy_status.retrieve.all': {
			o: o4
			login_required: false
			cache: 24 * 60
		}
		'search.metabib.record_to_descriptors': {
			i: (id) -> [{'record': id}]
			o: (data) ->
				x = data.payload[0]
				x.descriptors = fm.fieldmap x.descriptors
				return x
			login_required: false
			cache: 5
		}

		'search': {
			action: (d, m, search) ->
				# FIXME: eg api presumes patron.settings.retrieve while session.create.
				limit = if logged_in() then auth.session.settings['opac.hits_per_page'] else 10

				switch search.type
					when 'advanced'
						method = 'search.biblio.multiclass.query'
						request = $.extend({
							offset: 0
							limit: limit
						}, search)
					when 'lccn'
						method = 'search.biblio.marc'
						request = {
							search: [{
								term: search.term
								restrict: [{'tag': '010', 'subfield': '_'}]
							}]
							offset: 0
							limit: limit
						}
					when 'marc'
						method = 'search.biblio.marc'
						request = search
					when 'isbn'
						method = 'search.biblio.isbn'
						request = search
					when 'issn'
						method = 'search.biblio.issn'
						request = search
					when 'tcn'
						method = 'search.biblio.tcn'
						request = search
					else
						throw {
							name: 'BadSearch'
							message: 'Unknown search type'
						}

				openils method, request, (result) -> d.call result
		}
		'search.google_books': {
			cache: 24 * 60
			login_required: false
			action: (d, method, isbn) ->
				isbn = isbn.match(/^\d+/)[0]
				$.getJSON "http://books.google.com/books?jscmd=viewapi&bibkeys=#{isbn}&callback=?", (info) ->
					return unless info = info[isbn]
					info.isbn = isbn # So we can have access to the filtered ISBN
					d.call info
		}
		'search.google_books_rating': {
			cache: 24 * 60
			login_required: false
			action: (d, method, isbn) ->
				openils 'search.google_books', isbn, (info) ->
					id = info.info_url.split('id=')[1].split('&')[0]
					$.getJSON "http://www.google.com/books/feeds/volumes/#{id}?alt=json-in-script&callback=?", (info) ->
						return unless ratings = info.entry.gd$rating
						ret = {}
						$.each ratings, (k, v) -> ret[k] = Number v
						d.call ret
		}
		'search.extras': {
			cache: 24 * 60
			login_required: false
			action: (d, method, request) ->
				$.ajax {
					dataType: 'html'
					success: (data) -> d.call data
					type: 'GET'
					url: "/opac/extras/ac/#{request.type}/small/#{request.isbn}"
				}
		}
		'': {} # terminates the object
	}

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
		lookup = eg_services[method]
		if lookup is undefined
			names = []
			names.push(n) for n in eg_services when n
			return names

		d = new Deferred()

		# if 2nd argument refers to a function,
		# then it must be the success callback and param is a null value
		if typeof request is 'function'
			success = request
			request = null

		if typeof success is 'function'
			d = d.next success

		action = lookup.action or make_request
		if lookup.cache and not lookup.login_required
			cache d, method, request
		else
			action d, method, request
		return d

	# FIXME: rename to default_action, move d to last pos'n of argument list.
	make_request = (d, method, request) ->

		lookup = eg_services[method]

		# If the call requires the user to be logged in, and the user isn't,
		# trigger the login window.
		if lookup.login_required
			unless auth.session.id and auth.session.timeout > date.now()
				$('.login_window').trigger 'login_required', [new Deferred().next -> make_request d, method, request]
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

				            d.call data.payload[0]
				            reset_timeout()
				            return

				# data.payload.length could be zero
				cb_data = {}
				try
					cb_data = if lookup.o then lookup.o data else data.payload[0]
					cb_data = fm.ret_types[lookup.type](cb_data) if lookup.type
				catch e
					$().publish 'prompt', ['Client error', e.debug] if e.status and e.status isnt 200
					cb_data = e
				finally
					# FIXME: after all of the above calculation, cb_data could be an ilsevent object.
					d.call cb_data
					reset_timeout()
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

	cache = ( ->
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

		get = (d, method, request) ->
			lookup = eg_services[method]
			action = lookup.action or make_request
			k = key method, request
			entry = cache[k]
			expiry = lookup.cache
			expiry *= 60 * 1000

			if (entry?.timestamp + expiry) > date.now()
				next -> d.call entry.data
				return d

			queue[k] = [] if queue[k] is undefined
			queue[k].push(d)
			return d if entry is false # There's already a request in progress for this item.
			cache[k] = false

			req_deferred = new Deferred()
			req_deferred.next (result) ->
				entry = {
					timestamp: date.now()
					data: result
				}
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

		return get
	)()


	# Persist authentication session parameters,
	# including the user object provided by a service call to auth.session.retrieve

	no_session = {
		session:
			cryptkey: null
			id: null
			time: null
			user: {}
	}
	auth = {}
	$.extend true, auth, no_session

	setup_timeout = (authtime) ->
		clicked_in_time = false

		$.each timeouts, -> @cancel()
		timeouts = []
		return if authtime <= 0

		timeouts.push wait(authtime).next ->
			unless clicked_in_time
				openils 'auth.session.delete'
				$().publish 'display_home'

		timeouts.push wait(authtime - 60).next ->
			relogin = ->
				if logged_in()
					clicked_in_time = true
					openils 'auth.session.retrieve'
				return false
			$().publish 'prompt', ['Your login session', 'will timeout in 1 minute unless there is activity.', 60 * 1000, relogin]

	reset_timeout = ->
		if auth.session.id and auth.session.timeout > date.now()
			auth.session.timeout = date.now() + (auth.session.time * 1000)
			setup_timeout auth.session.time

	@openils = openils
	@auth = auth

	# Check if the user is logged in. If their session has expired but we
	# still have login state lying around, force a logout.
	@logged_in = logged_in = ->
		if auth.session.id
			if auth.session.timeout > date.now()
				return auth.session.id
			openils 'auth.session.delete'
		return false

	return @
