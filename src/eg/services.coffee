# Dictionary of ajax calls keyed by name of Evergreen service method

define [
	'jquery'
	'md5'
	'eg/fieldmapper'
	'eg/date'
	'eg/eg_api'
	'eg/auth'
	'exports'
], ($, md5, fm, date, eg, auth, services) ->

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
	$.extend true, services,

		'actor.container.create':
			i: (x) ->
				cbreb =
					items: null
					btype: 'bookbag'
					id: null
					name: ''
					owner: auth.session.user.id
					pub: false
				[auth.session.id, 'biblio', fm.mapfield { cbreb: $.extend cbreb, x }]
			o: o1
			type: 'number'
			login_required: true

		'actor.container.full_delete':
			i: (id) -> [auth.session.id, 'biblio', id]
			o: o1
			type: 'number'
			login_required: true

		'actor.container.retrieve_by_class':
			i: (id) -> [auth.session.id, id or auth.session.user.id, 'biblio', 'bookbag']
			o: o3
			login_required: true

		'actor.container.flesh':
			i: (bucket_id) -> [auth.session.id, 'biblio', bucket_id]
			o: o3
			login_required: true

		'actor.container.item.create':
			i: (item) -> [auth.session.id, 'biblio', fm.mapfield {cbrebi:item}]
			o: o1
			type: 'number'
			login_required: true

		'actor.container.item.delete':
			i: (id) -> [auth.session.id, 'biblio', id]
			o: o1
			type: 'number'
			login_required: true

		'actor.container.update':
			i: (cbreb) -> [auth.session.id, 'biblio', fm.mapfield {cbreb:cbreb}]
			o: o1
			type: 'number'
			login_required: true

		'actor.org_types.retrieve':
			o: o4
			login_required: false
			cache: 24 * 60

		# Gets all opac_visible ou nodes.
		'actor.org_tree.retrieve':
			o: o5
			login_required: false
			cache: 24 * 60

		'actor.org_tree.descendants.retrieve':
			i: (id) -> [id or 1]
			o: o6
			login_required: false
			cache: 24 * 60

		'actor.patron.settings.retrieve':
			i: i3
			o: (data) ->
				auth.session.settings = data.payload[0]
				auth.session.settings
			type: 'prefs'
			login_required: true

		'actor.patron.settings.update':
			i: (obj) -> [auth.session.id, auth.session.user.id, obj]
			type: 'number'
			login_required: true

		'actor.note.retrieve.all':
			i: (id) -> [auth.session.id, { patronid: id or auth.session.user.id, pub: 1 }]
			login_required: true

		'actor.ou_setting.ancestor_default':
			i: (request) -> [1, request] # [org_id, request]
			o: o1

		'actor.user.checked_out':
			i: i3
			login_required: true

		'actor.user.checked_out.authoritative':
			i: i3
			login_required: true

		'actor.user.checked_out.count':
			i: i3
			login_required: true
			# Ensure that response has a zero total property.
			o: (data) ->
				o = o1 data
				o.total = 0 unless o.total?
				o

		'actor.user.checked_out.count.authoritative':
			i: i3
			login_required: true
			o: (data) ->
				o = o1 data
				o.total = 0 unless o.total?
				o

		'actor.user.email.update':
			i: i2
			type: 'number'
			login_required: true

		'actor.user.password.update':
			i: (pw) -> [auth.session.id, pw.new_password, pw.old_password]
			type: 'number'
			login_required: true

		'actor.user.username.update':
			i: i2
			type: 'number'
			login_required: true

		'actor.user.fleshed.retrieve':
			i: i3
			o: o3
			login_required: true

		'actor.user.fleshed.retrieve_by_barcode':
			i: i2
			o: o3
			login_required: true

		'actor.user.fines.summary':
			i: i3
			o: o3
			login_required: true

		'actor.user.fines.summary.authoritative':
			i: i3
			o: o3
			login_required: true

		'actor.user.transactions.have_charge.fleshed':
			i: i3
			o: (data) -> fm.fieldmap $.map data.payload[0], (x) -> x.transaction
			login_required: true

		'actor.username.exists':
			i: i2
			type: 'number'
			login_required: true


		# input, username; output, encryption key
		'auth.authenticate.init':
			i: i1
			o: (data) -> auth.session.cryptkey = o1 data
			login_required: false

		# input, {username: un, password: pw, type: 'staff', org: ou_id}
		# output, {authtoken: sessionID, authtime: sessiontime}
		'auth.authenticate.complete':
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

				$.ajaxSetup $.extend {}, eg.ajaxOptions, {
					beforeSend: (xhr) -> xhr.setRequestHeader 'X-OILS-Authtoken', auth.session.id
				}

				auth.setup_timeout response.authtime
				return response
			login_required: false

		# Combine authenticate.init and authenticate.complete
		'auth.session.create':
			action: (d, method, o) ->
				# FIXME: the following two openils requests can be done in parallel.
				eg.openils('auth.authenticate.init', o.username)
				.next ->
					eg.openils 'actor.ou_setting.ancestor_default', 'opac.barcode_regex'
				.next (x) ->
						# If username is a barcode then convert username property to barcode property.
						# Barcode is determined by a regex defined by local sys admin
						# or by usernames beginning with a number.
						barcode = new RegExp if x?.value then "^#{x.value}$" else '^\\d+'
						if o.username.match barcode
							o.barcode = o.username
							delete o.username
				.next ->
					eg.openils 'auth.authenticate.complete', o
				.next (data) -> d.call data

		# input, sessionid; output, sessionid
		'auth.session.delete':
			i: i0
			o: (data) ->
				$.extend true, auth, auth.no_session
				$.ajaxSetup eg.ajaxOptions
				$().publish 'logout_event'
				auth.setup_timeout 0
				data.payload[0]
			login_required: false # Logging out multiple times is OK

		'auth.session.retrieve':
			i: i0
			o: (data) -> auth.session.user = o3 data
			login_required: true


		# input, hostname and client version ID; output, HTML page
		'auth.authenticate.confirm_the_server':
			action: (d, method, obj) ->
				$.ajax
					url: "/xul/rel_#{obj.client}/server"
					type: 'get'
					dataType: 'html'
					success: (data) -> d.call data

		'circ.open_non_cataloged_circulation.user':
			i: i3

		'circ.holds.id_list.retrieve.authoritative':
			i: i3
			o: o1
			login_required: true

		'circ.holds.retrieve':
			i: i3
			o: o3
			login_required: true

		'circ.hold.details.retrieve.authoritative':
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

		'circ.hold.queue_stats.retrieve':
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

		'circ.hold.status.retrieve':
			i: i2
			o: (data) ->
				switch Number data.payload[0]
					when 1 then [1, 'Waiting for copy to become available']
					when 2 then [2, 'Waiting for copy capture']
					when 3 then [3, 'In transit']
					when 4 then [4, 'Ready for Pickup']
					else ['-1', 'Error']
			login_required: true

		'circ.holds.create':
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

		'circ.hold.update':
			i: (ahr) -> [auth.session.id, fm.mapfield {ahr:ahr}]
			o: o1
			type: 'number'
			login_required: true

		'circ.hold.cancel':
			i: i2
			o: o1
			type: 'number'
			login_required: true

		'circ.title_hold.is_possible':
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

		'circ.money.billing.retrieve.all':
			i: i2
			o: o3
			login_required: true

		'circ.retrieve':
			i: i2
			o: o3
			login_required: true

		'circ.retrieve.authoritative':
			i: i2
			o: o3
			login_required: true

		'circ.renew':
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


		'ingest.full.biblio.record.readonly':
			i: i1

		'search.asset.call_number.retrieve':
			i: i1
			o: o3
			login_required: false
			cache: 5

		'search.asset.copy.retrieve':
			i: i1
			o: o3
			login_required: false
			cache: 5

		'search.asset.copy.retrieve_by_cn_label':
			i: (o) -> [o.id, o.cn, o.org_id]
			login_required: false
			cache: 5

		'search.asset.copy.fleshed2.find_by_barcode':
			i: i1
			o: o3
			login_required: false
			cache: 5

		'search.asset.copy.fleshed2.retrieve':
			i: i1
			o: o3
			login_required: false
			cache: 5

		'search.authority.crossref.batch':
			i: (obj, callback) ->
				input = []
				$.each obj, (type, obj2) ->
					$.each obj2, (n) ->
						input.push [type, n]
				[input]
			login_required: false
			cache: 5

		'search.bib_id.by_barcode':
			i: i1
			type: 'number'
			login_required: false
			cache: 5

		'search.biblio.bib_level_map.retrieve.all':
			o: o3
			login_required: false
			cache: 24 * 60

		'search.biblio.lit_form_map.retrieve.all':
			o: o3
			login_required: false
			cache: 24 * 60

		'search.biblio.item_form_map.retrieve.all':
			o: o3
			login_required: false
			cache: 24 * 60

		'search.biblio.item_type_map.retrieve.all':
			o: o3
			login_required: false
			cache: 24 * 60

		'search.biblio.audience_map.retrieve.all':
			o: o3
			login_required: false
			cache: 24 * 60

		'search.biblio.isbn':
			i: s1
			type: 'search'
			login_required: false,
			cache: 5

		'search.biblio.issn':
			i: s1
			type: 'search'
			login_required: false
			cache: 5

		'search.biblio.marc':
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

		'search.biblio.mods_from_copy':
			i: i1
			o: o3
			login_required: false
			cache: 5

		'search.biblio.tcn':
			i: s1
			type: 'search'
			login_required: false
			cache: 5

		'search.biblio.multiclass.query':
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

		'search.biblio.record_entry.slim.retrieve':
			i: i1
			o: o3
			login_required: false
			cache: 5

		'search.biblio.record.mods_slim.retrieve':
			i: i1
			o: o3
			login_required: false
			cache: 5

		'search.biblio.metarecord.mods_slim.retrieve':
			i: i1
			o: o3
			login_required: false
			cache: 5

		'search.biblio.record.copy_count':
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

		'search.biblio.record.html':
			i: i1
			login_required: false
			cache: 5

		'search.biblio.copy_counts.summary.retrieve':
			i: i1
			o: (data) ->
				data = data.payload[0]
				# [ [org_id, callnumber_label, {status1=>count1, status2=>count2}], ]
				# [ {org_id=>{callnumber_label=>{status1=>count1, status2=>count2}}}, ]
				# where statusn is asset.copy.status which is an FK to config.copy_status
				# and copy_status is opac_visible
				$.each data, (n) ->
					data[n] =
						org_id: Number @[0]
						callnumber: @[1]
						available: @[2]
				return data
			login_required: false
			cache: 5

		'search.biblio.copy_location_counts.summary.retrieve':
			i: (o) -> [o.id, o.org_id, o.depth]
			o: (data) ->
				data = data.payload[0]
				# [ [org_id, callnumber_label, copy_location, {status1=>count1, status2=>count2}], ]
				$.each data, (n) ->
					data[n] =
						org_id: Number @[0]
						callnumber: @[1]
						copylocation: @[2]
						available: @[3]
				return data
			login_required: false
			cache: 5

		'search.callnumber.retrieve':
			i: i1
			o: o3
			login_required: false
			cache: 5

		'search.callnumber.browse':
			i: (o) -> [o.callnumber or '', o.org_id or 1, o.size or 9, o.offset or 0]
			o: (data) ->
				$.each data.payload[0], (n, data) ->
					data.cn = fm.fieldmap(data.cn)
					data.mods = fm.fieldmap(data.mods)
				data.payload[0]
			login_required: false
			cache: 5

		'search.config.copy_status.retrieve.all':
			o: o4
			login_required: false
			cache: 24 * 60

		'search.metabib.record_to_descriptors':
			i: (id) -> [{'record': id}]
			o: (data) ->
				x = data.payload[0]
				x.descriptors = fm.fieldmap x.descriptors
				return x
			login_required: false
			cache: 5

		'search':
			action: (d, m, search) ->
				# FIXME: eg api presumes patron.settings.retrieve while session.create.
				limit = if auth.logged_in() then auth.session.settings['opac.hits_per_page'] else 10

				switch search.type
					when 'advanced'
						method = 'search.biblio.multiclass.query'
						request = $.extend({
							offset: 0
							limit: limit
						}, search)
					when 'lccn'
						method = 'search.biblio.marc'
						request =
							search: [{
								term: search.term
								restrict: [{'tag': '010', 'subfield': '_'}]
							}]
							offset: 0
							limit: limit
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

				eg.openils method, request, (result) -> d.call result

		'search.google_books':
			cache: 24 * 60
			login_required: false
			action: (d, method, isbn) ->
				isbn = isbn.match(/^\d+/)[0]
				$.getJSON "http://books.google.com/books?jscmd=viewapi&bibkeys=#{isbn}&callback=?", (info) ->
					return unless info = info[isbn]
					info.isbn = isbn # So we can have access to the filtered ISBN
					d.call info

		'search.google_books_rating':
			cache: 24 * 60
			login_required: false
			action: (d, method, isbn) ->
				eg.openils 'search.google_books', isbn, (info) ->
					id = info.info_url.split('id=')[1].split('&')[0]
					$.getJSON "http://www.google.com/books/feeds/volumes/#{id}?alt=json-in-script&callback=?", (info) ->
						return unless ratings = info.entry.gd$rating
						ret = {}
						$.each ratings, (k, v) -> ret[k] = Number v
						d.call ret

		'search.extras':
			cache: 24 * 60
			login_required: false
			action: (d, method, request) ->
				$.ajax
					dataType: 'html'
					success: (data) -> d.call data
					type: 'GET'
					url: "/opac/extras/ac/#{request.type}/small/#{request.isbn}"

		'': {} # terminates the object
	return
