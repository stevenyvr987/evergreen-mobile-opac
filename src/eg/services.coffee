# Dictionary of ajax calls keyed by name of Evergreen service method

define [
	'eg/fieldmapper'
	'eg/date'
	'eg/eg_api'
	'eg/auth'
	'exports'
	'md5'
], (fm, date, eg, auth, services) -> (($) ->

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

	# FIXME: this is a hack to remember what possible version of the API we are using
	api_version = '2.0'

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
			t: 'number'
			s: true

		'actor.container.full_delete':
			i: (id) -> [auth.session.id, 'biblio', id]
			t: 'number'
			s: true

		'actor.container.retrieve_by_class':
			i: (id) -> [auth.session.id, id or auth.session.user.id, 'biblio', 'bookbag']
			o: o3
			s: true

		'actor.container.flesh':
			i: (bucket_id) -> [auth.session.id, 'biblio', bucket_id]
			o: o3
			s: true

		'actor.container.item.create':
			i: (item) -> [auth.session.id, 'biblio', fm.mapfield cbrebi: item]
			t: 'number'
			s: true

		'actor.container.item.delete':
			i: (id) -> [auth.session.id, 'biblio', id]
			t: 'number'
			s: true

		'actor.container.update':
			i: (cbreb) -> [auth.session.id, 'biblio', fm.mapfield cbreb: cbreb]
			t: 'number'
			s: true

		'actor.org_types.retrieve':
			o: o4
			c: 24 * 60

		# Gets all opac_visible ou nodes.
		'actor.org_tree.retrieve':
			o: o5
			c: 24 * 60

		'actor.org_tree.descendants.retrieve':
			i: (id) -> [id or 1]
			o: o6
			c: 24 * 60

		'actor.patron.settings.retrieve':
			i: i3
			o: (data) ->
				auth.session.settings = o1 data
				auth.session.settings
			t: 'prefs'
			s: true

		'actor.patron.settings.update':
			i: (obj) -> [auth.session.id, auth.session.user.id, obj]
			t: 'number'
			s: true

		'actor.note.retrieve.all':
			i: (id) -> [auth.session.id, patronid: id or auth.session.user.id, pub: 1]
			s: true

		'actor.ou_setting.ancestor_default':
			i: (request) -> [1, request] # [org_id, request]

		'actor.user.checked_out':
			i: i3
			s: true

		'actor.user.checked_out.authoritative':
			i: i3
			s: true

		'actor.user.checked_out.count':
			i: i3
			s: true
			# Ensure that response has a zero total property.
			o: (data) ->
				o = o1 data
				o.total = 0 unless o.total?
				o

		'actor.user.checked_out.count.authoritative':
			i: i3
			s: true
			o: (data) ->
				o = o1 data
				o.total = 0 unless o.total?
				o

		'actor.user.email.update':
			i: i2
			t: 'number'
			s: true

		'actor.user.password.update':
			i: (pw) -> [auth.session.id, pw.new_password, pw.old_password]
			t: 'number'
			s: true

		'actor.user.username.update':
			i: i2
			t: 'number'
			s: true

		'actor.user.fleshed.retrieve':
			i: i3
			o: o3
			s: true

		'actor.user.fleshed.retrieve_by_barcode':
			i: i2
			o: o3
			s: true

		'actor.user.fines.summary':
			i: i3
			o: o3
			s: true

		'actor.user.payments.retrieve':
			i: (obj) -> [auth.session.id, auth.session.user.id, obj]
			o: (o) ->
				x.mp = fm.fieldmap x.mp for x in o.payload
				o.payload
			s: true

		# Where there are zero fines for certain types of patrons, it's
		# possible for the server response to be a null object instead of an
		# mous data object, in which case, we replace the response with an mous
		# containing zero fines.
		'actor.user.fines.summary.authoritative':
			i: i3
			o: (x) -> # should be o3 if all was well
				ox = o1 x
				ox = { __c: 'mous', __p: ['0.0', '0.0', '0.0', 0] } unless ox
				fm.fieldmap ox
			s: true

		'actor.user.transactions.have_charge.fleshed':
			i: i3
			o: (data) ->
				$.map o1(data), (x) ->
					x.circ = fm.fieldmap x.circ or {}
					x.mvr = fm.fieldmap x.record or {}
					x.mbts = fm.fieldmap x.transaction or {}
					delete x.record
					delete x.transaction
					return x
			s: true

		'actor.username.exists':
			i: i2
			t: 'number'
			s: true


		# input, username; output, encryption key
		'auth.authenticate.init':
			i: i1
			o: (data) -> auth.session.cryptkey = o1 data

		# input, {username: un, password: pw, type: 'staff', org: ou_id}
		# output, {authtoken: sessionID, authtime: sessiontime}
		'auth.authenticate.complete':
			i: (o) ->
				o.password = hex_md5 auth.session.cryptkey + hex_md5 o.password
				[o]
			o: (data) ->
				response = o1 data

				if data.status isnt undefined and data.status isnt 200
					auth.session.id = 0
					throw data
				if response.ilsevent isnt undefined and response.ilsevent isnt 0
					auth.session.id = 0
					throw response

				response = response.payload; # there is an inner payload!
				auth.session.id = response.authtoken
				auth.session.time = response.authtime
				auth.session.timeout = date.now() + (response.authtime * 1000)

				$.ajaxSetup $.extend {}, eg.ajaxOptions,
					beforeSend: (xhr) -> xhr.setRequestHeader 'X-OILS-Authtoken', auth.session.id

				auth.setup_timeout response.authtime
				return response

		# Combine authenticate.init and authenticate.complete
		'auth.session.create':
			action: (method, o, d) ->

				# Abort the action if username or password is empty.
				un = o.username
				return false unless un and (un.replace /\s+/, "").length
				pw = o.password
				return false unless pw and (pw.replace /\s+/, "").length

				parallel(
					cryptkey: eg.openils 'auth.authenticate.init', un
					regex: eg.openils 'actor.ou_setting.ancestor_default', 'opac.barcode_regex'
				).next (x) ->
					# If username is a barcode then convert username property to barcode property.
					# Barcode is determined by a regex defined by local sys admin
					# or by usernames beginning with a number.
					barcode = new RegExp if x.regex?.value then "^#{x.regex.value}$" else '^\\d+'
					if un.match barcode
						o.barcode = un
						delete o.username

					eg.openils 'auth.authenticate.complete', o, (resp) ->

						# Response handler is called even when authentication
						# fails because of bad credentials.
						return if resp.ilsevent?

						parallel([
							eg.openils 'actor.patron.settings.retrieve'
							eg.openils 'auth.session.retrieve'
						]).next ->
							d.call resp
							return
						return
					return
				return

		# input, sessionid; output, sessionid
		'auth.session.delete':
			i: i0
			o: (data) ->
				$.extend true, auth, auth.no_session
				$.ajaxSetup eg.ajaxOptions
				$().publish 'session.logout'
				auth.setup_timeout 0
				o1 data

		'auth.session.retrieve':
			i: i0
			o: (data) -> auth.session.user = o3 data
			s: true


		# input, hostname and client version ID; output, HTML page
		'auth.authenticate.confirm_the_server':
			action: (method, obj, d) ->
				$.ajax
					url: "/xul/rel_#{obj.client}/server"
					t: 'get'
					dataType: 'html'
					success: (data) -> d.call data

		'circ.open_non_cataloged_circulation.user':
			i: i3
			s: true

		'circ.holds.id_list.retrieve.authoritative':
			i: i3
			s: true

		'circ.holds.retrieve':
			i: i3
			o: o3
			s: true

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
			s: true

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
			s: true

		'circ.hold.status.retrieve':
			i: i2
			o: (data) ->
				switch Number o1 data
					when 1 then [1, 'Waiting for copy to become available']
					when 2 then [2, 'Waiting for copy capture']
					when 3 then [3, 'In transit']
					when 4 then [4, 'Ready for Pickup']
					else ['-1', 'Error']
			s: true

		'circ.holds.create':

			i: (x) ->

				user = auth.session.user
				cfg = auth.session.settings

				ahr = $.extend
					hold_type: 'T'
					usr: user.id
					pickup_lib: cfg?['opac.default_pickup_location'] or user.home_ou
				, x

				# If there are default configurations, we transfer them over to
				# the hold request.
				if cfg
					if (/email/i).test cfg['opac.hold_notify']
						ahr.email_notify = true
					if (/phone/i).test cfg['opac.hold_notify']
						ahr.phone_notify =
							cfg['opac.default_phone'] or user.day_phone or user.evening_phone or user.other_phone
					if (/sms/i).test cfg['opac.hold_notify']
						ahr.sms_notify = cfg['opac.default_sms_notify']
						ahr.sms_carrier = cfg['opac.default_sms_carrier']

				[auth.session.id, fm.mapfield ahr: ahr]

			t: 'number'
			s: true

		'circ.hold.update':
			i: (ahr) -> [auth.session.id, fm.mapfield ahr: ahr]
			t: 'number'
			s: true

		'circ.hold.cancel':
			i: i2
			t: 'number'
			s: true

		'circ.title_hold.is_possible':
			i: (x) ->
				obj = $.extend
					patronid: auth.session.user.id
					pickup_lib: auth.session.settings['opac.default_pickup_location'] or auth.session.user.home_ou
				, x
				[auth.session.id, obj]
			s: true

		'circ.money.billing.retrieve.all':
			i: i2
			o: o3
			s: true

		'circ.money.payment':
			i: (x) ->
				obj = userid: auth.session.user.id
				$.extend obj, x
				[auth.session.id, obj, auth.session.user.last_xact_id]
			o: o1
			s: true

		'circ.money.payment_receipt.email':
			i: i2
			o: o1
			s: true

		'circ.money.payment_receipt.print':
			i: i2
			o: (atev) ->
				atev = fm.fieldmap o1 atev
				atev.template_output = fm.fieldmap atev.template_output
				atev
			s: true

		'circ.retrieve':
			i: i2
			o: o3
			s: true

		'circ.retrieve.authoritative':
			i: i2
			o: o3
			s: true

		'circ.renew':
			i: (copy) ->
				[auth.session.id,
					patron: auth.session.user.id
					copyid: copy
					opac_renewal: 1
				]
			o: (result) ->
				result = result.payload[0]
				if result.textcode is 'SUCCESS'
					result = result.payload
					result.circ = fm.fieldmap result.circ
					result.copy = fm.fieldmap result.copy
					result.record = fm.fieldmap result.record
				result
			s: true


		'ingest.full.biblio.record.readonly':
			i: i1

		'search.asset.call_number.retrieve':
			i: i1
			o: o3
			c: 5

		'search.asset.copy.retrieve':
			i: i1
			o: o3
			c: 5

		'search.asset.copy.retrieve_by_cn_label':
			i: (o) ->
				# If we are using an earlier version of the API, then we need
				# to submit only callnumber label instead of a list of prefix,
				# label, and suffix.
				o.cn = o.cn[1] if api_version is '2.0'
				[o.id, o.cn, o.org_id]
			c: 5

		'search.asset.copy.fleshed2.find_by_barcode':
			i: i1
			o: o3
			c: 5

		'search.asset.copy.fleshed2.retrieve':
			i: i1
			o: o3
			c: 5

		'search.authority.crossref.batch':
			i: (obj, callback) ->
				input = []
				$.each obj, (type, obj2) ->
					$.each obj2, (n) ->
						input.push [type, n]
				[input]
			c: 5

		'search.bib_id.by_barcode':
			i: i1
			t: 'number'
			c: 5

		'search.biblio.bib_level_map.retrieve.all':
			o: o3
			c: 24 * 60

		'search.biblio.lit_form_map.retrieve.all':
			o: o3
			c: 24 * 60

		'search.biblio.item_form_map.retrieve.all':
			o: o3
			c: 24 * 60

		'search.biblio.item_type_map.retrieve.all':
			o: o3
			c: 24 * 60

		'search.biblio.audience_map.retrieve.all':
			o: o3
			c: 24 * 60

		'search.biblio.isbn':
			i: s1
			t: 'search'
			c: 5

		'search.biblio.issn':
			i: s1
			t: 'search'
			c: 5

		'search.biblio.marc':
			i: (search) -> [
				searches: search.search
				limit: 200
				org_unit: search.org_unit or 1
				depth: search.depth or 0
				sort: search.sort
				sort_dir: search.sort_dir
				search.limit
				search.offset
			]
			t: 'search'
			c: 5

		'search.biblio.mods_from_copy':
			i: i1
			o: o3
			c: 5

		'search.biblio.tcn':
			i: s1
			t: 'search'
			c: 5

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
				x = o1 data
				# flatten the list of ids
				x.ids = $.map x.ids, (v) -> v
				return x
			t: 'search'
			c: 5

		'search.biblio.record_entry.slim.retrieve':
			i: i1
			o: o3
			c: 5

		'search.biblio.record.mods_slim.retrieve':
			i: i1
			o: o3
			c: 5

		'search.biblio.metarecord.mods_slim.retrieve':
			i: i1
			o: o3
			c: 5

		'search.biblio.record.copy_count':
			i: (o) -> [o.location, o.id]
			o: (data) ->
				x = o1 data
				y = {}
				$.each x, (i, xi) ->
					y[i] =
						available: xi.available
						count: xi.count
						depth: xi.depth
						org_unit: xi.org_unit
				return y
			c: 5

		'search.biblio.record.html':
			i: i1
			c: 5

		'search.biblio.copy_counts.summary.retrieve':
			i: i1
			o: (data) ->
				data = o1 data
				# [ [org_id, callnumber_label, {status1=>count1, status2=>count2}], ]
				# [ {org_id=>{callnumber_label=>{status1=>count1, status2=>count2}}}, ]
				# where statusn is asset.copy.status which is an FK to config.copy_status
				# and copy_status is opac_visible
				$.each data, (n) ->
					api_version = if @length is 3 then '2.0' else '2.2'
					data[n] = if @length is 3 then {
						org_id: Number @[0]
						callnumber: [ '', @[1], '' ]
						available: @[2]
					} else { # EG version 2.2+
						org_id: Number @[0]
						callnumber: [ @[1], @[2], @[3] ]
						available: @[4]
					}
				return data
			c: 5

		'search.biblio.copy_location_counts.summary.retrieve':
			i: (o) -> [o.id, o.org_id, o.depth]
			o: (data) ->
				data = o1 data
				# [ [org_id, callnumber_label, copy_location, {status1=>count1, status2=>count2}], ]
				# or (EG version 2.2+)
				# [ [org_id, callnumber_prefix, callnumber_label, callnumber_suffix, copy_location, {status1=>count1, status2=>count2}], ]
				$.each data, (n) ->
					api_version = if @length is 3 then '2.0' else '2.2'
					data[n] = if @length is 4 then {
						org_id: Number @[0]
						callnumber: [ '', @[1], '' ]
						copylocation: @[2]
						available: @[3]
					} else { # EG version 2.2+
						org_id: Number @[0]
						callnumber: [ @[1], @[2], @[3] ]
						copylocation: @[4]
						available: @[5]
					}
				return data
			c: 5

		'search.callnumber.retrieve':
			i: i1
			o: o3
			c: 5

		'search.callnumber.browse':
			i: (o) -> [o.callnumber or '', o.org_id or 1, o.size or 9, o.offset or 0]
			o: (data) ->
				$.each o1 data, (n, data) ->
					data.cn = fm.fieldmap(data.cn)
					data.mods = fm.fieldmap(data.mods)
				o1 data
			c: 5

		'search.config.copy_status.retrieve.all':
			o: o4
			c: 24 * 60

		'search.metabib.record_to_descriptors':
			i: (id) -> [record: id]
			o: (data) ->
				x = o1 data
				x.descriptors = fm.fieldmap x.descriptors
				return x
			c: 5

		'search':
			action: (m, search, d) ->
				# FIXME: eg api presumes patron.settings.retrieve while session.create.
				limit = if auth.logged_in() then auth.session.settings['opac.hits_per_page'] else 10

				switch search.type
					when 'advanced'
						method = 'search.biblio.multiclass.query'
						request = $.extend(
							offset: 0
							limit: limit
						, search)
					when 'lccn'
						method = 'search.biblio.marc'
						request =
							search: [
								term: search.term
								restrict: [tag: '010', subfield: '_']
							]
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
			c: 24 * 60
			action: (method, isbn, d) ->
				isbn = isbn.match(/^\d+/)[0]
				$.getJSON "http://books.google.com/books?jscmd=viewapi&bibkeys=#{isbn}&callback=?", (info) ->
					return unless info = info[isbn]
					info.isbn = isbn # So we can have access to the filtered ISBN
					d.call info

		'search.google_books_rating':
			c: 24 * 60
			action: (method, isbn, d) ->
				eg.openils 'search.google_books', isbn, (info) ->
					id = info.info_url.split('id=')[1].split('&')[0]
					$.getJSON "http://www.google.com/books/feeds/volumes/#{id}?alt=json-in-script&callback=?", (info) ->
						return unless ratings = info.entry.gd$rating
						ret = {}
						$.each ratings, (k, v) -> ret[k] = Number v
						d.call ret

		'search.extras':
			c: 24 * 60
			action: (method, request, d) ->
				$.ajax
					dataType: 'html'
					success: (data) -> d.call data
					type: 'GET'
					url: "/opac/extras/ac/#{request.type}/small/#{request.isbn}"

		'': {} # terminates the object
	return
)(jQuery)
