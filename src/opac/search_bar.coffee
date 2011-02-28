# search_bar.coffee
#
# Plugin to provide a basic search bar.
# Publishes and subscribes to the 'search' data channel.

module 'opac.search_bar', imports(
	'eg.eg_api'
	'plugin'
	'opac.ou_tree'
	'opac.sort'
), (eg) ->

	# Option settings for search bar selectors that are not dynamically built.
	# FIXME: item_type names are displayed in the search form,
	# but in the result list, a different set of names is used; confusing.
	settings = {}
	defaults =
		default_class:
			keyword: 'Keyword'
			title:   'Title'
			author:  'Author'
			subject: 'Subject'
			series:  'Series'

		search_term_verb:
			' ': 'Contains'
			'-': 'Does not contain'
			'=': 'Matches exactly'

		item_type:
			'': 'All Item Types'
			at: 'Books'
			i:  'Audiobooks'
			g:  'Video Recordings'
			j:  'Music'
			m:  'Electronic Resources'

		language:
			'' : 'All Languages'
			eng: 'English'
			spa: 'Spanish'
			fre: 'French'
			ger: 'German'
			ita: 'Italian'
			chi: 'Chinese'
			jpn: 'Japanese'
			kor: 'Korean'
			dut: 'Dutch'
			gre: 'Greek, Modern (1453- )'
			lat: 'Latin'
			vie: 'Vietnamese'
			rus: 'Russian'
			nor: 'Norwegian'
			wel: 'Welsh'
			pau: 'Palauan'
			swe: 'Swedish'
			nav: 'Navajo'

		pub_year_verb:
			'is': 'Is'
			before: 'Before'
			after: 'After'
			between: 'Between'

		refresh: ''

	# Search form contains input and selector elements that are named after request parameters.
	# FIXME: rename 'type' to 'search_type'; more descriptive.
	search_form = '''
	<form class="search_form_advanced">
		<div class="search term" />
		<div>
			<span class="org_unit_selector" />
			<span class="advanced search org_unit_available"><input type="checkbox" name="available" value="1">Limit to Available</input></span>
		</div>
		<div>
			<select name="facets" title="Filter by formats"/>
			<select multiple size="4" class="advanced search" name="language" title="Filter by language"/>
		</div>
		<div class="advanced search publication year">
			<span>Publication Year</span>
			<select name="pub_year_verb" />
			<input type="text" name="year_begin" maxlength="4" size="4"/>
			<span class="year_end">and <input name="year_end" maxlength="4" size="4"/></span>
		</div>
		<div class="sort_chooser" />
		<input name="offset" value="0" type="hidden" />
		<input name="limit" value="10" type="hidden" />
		<input name="visibility_limit" value="1000" type="hidden" />
		<input name="type" value="advanced" type="hidden" />
		<button type="submit">Search</button>
		<button type="reset">Reset</button>
		<button type="button" class="search type" />
	</form>
	'''

	search_row = '''
	<div class="search row">
		<button type="button" title="Delete this search row" class="search row delete">-</button>
		<select name="default_class" />
		<select name="search_term_verb" />
		<input name="term" type="text" />
		<button type="button" title="Add new search row" class="search row add">+</button>
	</div>
	'''

	search_row_simple = '''
	<div class="search row">
		<select name="default_class" />
		Contains
		<input name="term" type="text" />
	</div>
	'''

	# Build select options based on plugin options and default settings.
	build_options = ->
		return unless o = settings[ $(@).attr 'name' ]
		return if $(@).find('option').length
		for v, n of o
			$option = $("<option value=\"#{v}\">#{n}</option>")
			$option.attr 'selected', 'selected' unless v
			$(@).append $option

	# Switch search form from simple to advanced format.
	show_advanced = ->
		$x = $('.search.term', @)
		$x.hide().empty()
		.append(search_row)
		.append(search_row)
		.append(search_row)
		.find('select').each -> build_options.call @
		$x.fadeIn 1000
		$('.search.advanced', @).fadeIn 1000
		$('select:[name=facets]', @).hide().attr
			multiple: true
			size: 4
		.fadeIn 1000
		$('input[name=term]', @).first().focus()
		return false

	# Switch search form from advanced to simple format.
	show_simple = ->
		$x = $('.search.term', @)
		$x.hide().empty()
		.append(search_row_simple)
		.find('select').each -> build_options.call @
		$x.fadeIn 1000
		$('.search.advanced', @).fadeOut 1000
		$('select:[name=facets]', @).hide().attr
			multiple: false
			size: 1
		.fadeIn 1000
		$('input[name=term]', @).first().focus()
		return false

	reset_search_form = ->
		$('input[type=text]', @).val ''
		$('input[type=checkbox]', @).attr 'checked', false
		$('select', @).val ''
		$('.sort select', @).change() # FIXME: pokes into sort chooser`
		return false

	# Define search bar plugin.
	$.fn.search_bar = (options) ->
		settings = $.extend {}, defaults, options

		@plugin('basic_search search_bar').html search_form

		# Build the ou selector once; default selection is the root node.
		$('.org_unit_selector', @).ou_tree
			'all': true
			'selected': if window.query?.ol? then null else 'Search all libraries'
			'indent': '_ '

		# Build the sort chooser once.
		$('.sort_chooser', @).sort_chooser()

		# Build selector options.
		$('select', @).each -> build_options.call @

		# Initially, show simple search form.
		show_simple.call @

		# Initialize search type button to toggle to Advanced search form.
		$('.search.type', @).text('Advanced')
		# Toggle between advanced and simple search form.
		.toggle(
			(e) =>
				$(e.target).text('Simple')
				.attr 'title', 'Show simple search form'
				show_advanced.call @
				reset_search_form.call @
		,
			(e) =>
				$(e.target).text('Advanced')
				.attr 'title', 'Show advanced search form'
				show_simple.call @
				reset_search_form.call @
		)

		# Handle button clicks to add or delete search rows.
		@delegate 'button.search.row', 'click', (e) =>
			$t = $(e.target)
			$p = $t.parent()
			if $t.hasClass 'delete'
				$p.remove() unless @find('div.search.row').length is 1
			else if $t.hasClass 'add'
				$p.append search_row
				@find('select', $p).each -> build_options.call @
			return false

		# Show or hide input text box for year end depending on verb chosen by user.
		$('.year_end', @).hide()
		@delegate 'select[name=pub_year_verb]', 'blur', (e) =>
			v = $(e.target).val()
			$el = $('.year_end', @)
			if v is 'between' then $el.show() else $el.hide()
			return false

		# Pressing esc key is same as clicking reset button.
		@keyup (e) =>
			switch e.keyCode
				when 27 then $('button[type=reset]', @).click()
			return false

		# Upon reset, nullify all input and select values.
		@delegate 'button[type=reset]', 'click', => reset_search_form.call @

		# Handle click of submit button.
		@submit ->

			# A valid submission needs at least one input terms to contain non-whitespace.
			ok = false
			$('input[name=term]', @).each ->
				if @value
					ok = true
					return false
			return false unless ok

			# Build request object from input and select values of search form.
			# Multiple values for a property name are cast into an array, eg, name:[1, 2]
			o = {}
			for x in $(@).children('form').serializeArray()
				unless o[x.name]?
					o[x.name] = x.value
				else
					unless $.isArray o[x.name]
						o[x.name] = [o[x.name]]
					o[x.name].push x.value

			# Calculate search depth from indentation of selected ou name.
			o.depth = $('select[name=org_unit]', $(@)).find(':selected').text().match(/\_ /g)?.length or 0

			# Publish the search form content on the search data channel.
			$(@).publish 'search', [o]
			return false


		# If there are other plugins publishing on the same channel,
		# subscribing to the channel will update this search object.
		@subscribe 'search', (o) ->

			$(':input', @).each ->
				switch @name
					when 'search', 'offset', 'visibility_limit' then return
					when 'item_type' then o.item_type = o.item_type.join ''
				$(@).val o[@name] if o[@name]

			$('.sort select', @).change() # FIXME: pokes into sort chooser`
			return
