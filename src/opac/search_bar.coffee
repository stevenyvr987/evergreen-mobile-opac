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

		pub_year_verb:
			'is': 'Is'
			before: 'Before'
			after: 'After'
			between: 'Between'

		sort:
			'': 'Relevance'
			'pubdate asc' : 'Publication date: ascending'
			'pubdate desc': 'Publication date: descending'
			'title asc' : 'Title: ascending'
			'title desc': 'Title: descending'
			'author asc' : 'Author: ascending'
			'author desc': 'Author: descending'

		refresh: ''

	# Search form contains input and selector elements that are named after request parameters.
	search_form = '''

	<form class="search_form_advanced">
		<div data-role="fieldcontain" class="search term">
			<div class="basic search row">
				<fieldset class="search row">
					<input type="search" name="term" value="" />
					<select name="default_class" data-native-menu="false" />
				</fieldset>
			</div>

			<div class="advanced search row">
			<fieldset data-role="controlgroup">
				<legend>Search terms</legend>
				<fieldset class="search row">
					<button data-role="none" type="button" title="Delete this search row" class="delete">-</button>
					<select data-role="none" name="default_class" />
					<select data-role="none" name="search_term_verb" />
					<input data-role="none" type="search" name="term" value="" />
					<button data-role="none" type="button" title="Add new search row" class="add">+</button>
				</fieldset>
				<fieldset class="search row">
					<button data-role="none" type="button" title="Delete this search row" class="delete">-</button>
					<select data-role="none" name="default_class" />
					<select data-role="none" name="search_term_verb" />
					<input data-role="none" type="search" name="term" value="" />
					<button data-role="none" type="button" title="Add new search row" class="add">+</button>
				</fieldset>
				<fieldset class="search row">
					<button data-role="none" type="button" title="Delete this search row" class="delete">-</button>
					<select data-role="none" name="default_class" />
					<select data-role="none" name="search_term_verb" />
					<input data-role="none" type="search" name="term" value="" />
					<button data-role="none" type="button" title="Add new search row" class="add">+</button>
				</fieldset>
			</fieldset>
			</div>
		</div>

		<div data-role="fieldcontain" class="search filters>
			<fieldset data-role="controlgroup">
				<legend>Filter search by</legend>
				<div class="org_unit_selector" />
				<label for="search_available">Limit to Available</label>
				<input type="checkbox" id="search_available" name="available" value="1" />
				<select name="facets" title="Filter by formats" data-native-menu="false" />
				<select name="item_type" title="Filter by formats" data-native-menu="false" />
				<div class="advanced">
					<select name="language" id="search_languages" multiple size="4" title="Filter by languages" data-native-menu="false" />
				</div>
			</fieldset>
		</div>

		<div data-role="fieldcontain" class="advanced publication year">
			<fieldset data-role="controlgroup">
				<legend>Publication Year</legend>
				<input data-role="none" type="radio" name="pub_year_verb" value="is" checked id="pub_year_is" />
				<label for="pub_year_is">Is</label>
				<input data-role="none" type="radio" name="pub_year_verb" value="before" id="pub_year_before" />
				<label for="pub_year_before">Before</label>
				<input data-role="none" type="radio" name="pub_year_verb" value="after" id="pub_year_after" />
				<label for="pub_year_after">After</label>
				<input data-role="none" type="radio" name="pub_year_verb" value="between" id="pub_year_between" />
				<label for="pub_year_between">Between</label>
				<input type="text" name="year_begin" maxlength="4" size="4" />
				<span class="year_end">and <input name="year_end" maxlength="4" size="4" /></span>
			</fieldset>
		</div>

		<div data-role="fieldcontain">
			<fieldset data-role="controlgroup">
				<legend>Sort results by</legend>
				<select name="sort" class="sort_chooser" data-native-menu="false" />
			</fieldset>
		</div>

		<div data-role="fieldcontain">
			<fieldset class="ui-grid-a">
				<div class="ui-block-a"><button type="reset">Reset</button></div>
				<div class="ui-block-b"><button type="submit">Search</button></div>
			</fieldset>
		</div>

		<input name="offset" value="0" type="hidden" />
		<input name="limit" value="10" type="hidden" />
		<input name="visibility_limit" value="1000" type="hidden" />
		<input name="type" value="advanced" type="hidden" />
	</form>

	<div>
		<select name="search_type" id="search_type_slider" data-role="slider" class="search type">
			<option value="basic">Advanced Search</option>
			<option value="advanced">Basic Search</option>
		</select>
	</div>
	'''

	# Build options for a given select menu element on the search form.
	build_options = ->
		# Skip the select element if it already has a list of options defined.
		return if $('option', @).length
		# Options are dynamically supplied in the settings object.
		$select = $(@)
		for v, n of settings[ $select.prop 'name' ]
			$select.append $("<option value=\"#{v}\">#{n}</option>")
		# Select the first option as the default
		$options = $('option', @)
		if $options.length
			$options.first().prop 'selected', 'selected'
		# Otherwise, remove the select element from the DOM if it has no options list.
		else
			$select.remove()
		return

	# Reset the visible input elements of the search form
	# that are not automatically taken care of by the browser upon a reset event.
	# This is a lot of fiddly work; it might be better to destroy the form and rebuild it.
	reset_search_form = ->
		$form = $('form', @)
		# Empty search inputs, visible or not.
		$('input[name="term"]', $form).val ''
		# Uncheck visibile checkboxes
		$('input[type=checkbox]:visible:checked', $form)
			.prop('checked', false)
			.checkboxradio 'refresh'
		# Set visible select menus to their default values
		for s in $('select:visible', $form)
			$s = $(s)
			$s.val $('option:first', $s).val()
			# Refresh the jQM version of the select menu unless it is part of a set that is not jQM'ed.
			$s.selectmenu 'refresh' unless $s.closest('.advanced.search.row').length
		# Hide the visible year end elements,
		$('.year_end:visible', $form).hide()
		# And publish a clear_data event to other interested plugins.
		$(@).publish 'clear_data'
		return

	# Flip between different types of search form
	flip_to = (type) ->
		if type is 'advanced'
			$('.advanced', @).show()
			$('.basic', @).hide()
		else
			$('.basic', @).show()
			$('.advanced', @).hide()

		$('input[name=term]', @).first().focus()
		reset_search_form.call @
		return false

	# Define search bar plugin.
	$.fn.search_bar = (options) ->
		settings = $.extend {}, defaults, options

		$form = $(search_form)

		# Build the ou selector once; default selection is the root node.
		$('.org_unit_selector', $form).ou_tree
			'all': true
			'selected': if window.query?.ol? then null else 'All Libraries'
			'indent': '_ '

		# Build selector options using options listed in settings object.
		$('select', $form).each -> build_options.call @

		# Initially, show simple search form.
		flip_to.call $form, 'basic'

		# Hide the year end elements
		$('.year_end', $form).hide()

		@plugin('basic_search search_bar').empty().append($form).trigger('create')

		# Handle a change in the flip switch between basic and advanced search form
		.delegate '.search.type', 'change', (e) =>
			flip_to.call @, $(e.target).val()

		# Handle button clicks to add search rows.
		.delegate 'button.add', 'click', (e) =>
			$p = $(e.target).closest 'fieldset'
			$p.after $p.clone true
			@find('select', $p).each -> build_options.call @
			return false

		# Handle button clicks to delete search rows.
		.delegate 'button.delete', 'click', (e) =>
			$p = $(e.target).closest 'fieldset'
			$n = $('div.advanced fieldset.search.row', @)
			$p.remove() unless $n.length is 1
			return false

		# Show or hide input text box for year end depending on verb chosen by user.
		.delegate 'input[name=pub_year_verb]', 'click', (e) =>
			between = $(e.target).val() is 'between'
			$yr_end = $('.year_end', @)
			if between then $yr_end.show() else $yr_end.hide()
			return

		# Pressing esc key is same as clicking reset button.
		.keyup (e) =>
			switch e.keyCode
				when 27 then $('button[type=reset]', @).click()
			return false

		# Upon reset, we nullify all input and select values.
		.delegate 'button[type=reset]', 'click', =>
			reset_search_form.call @

		# Handle submission events
		.submit ->

			$this = $(@)

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
			for x in $this.children('form').serializeArray()
				unless o[x.name]?
					o[x.name] = x.value
				else
					unless $.isArray o[x.name]
						o[x.name] = [o[x.name]]
					o[x.name].push x.value

			# Calculate search depth from indentation of selected ou name.
			o.depth = $('select[name=org_unit]', @).find(':selected').text().match(/\_ /g)?.length or 0

			# Publish the search form content on the search data channel.
			$this.publish 'search', [o]
			return false

		# Subscribe to publications of data on the search channel.
		.subscribe 'search', (o) ->
			# For now, we only handle a new author search.
			return unless o.default_class is 'author'
			# The corresponding changes are to revert to basic search form,
			# and to modify the search term in the form.
			flip_to.call @, 'basic'
			$('input[name="term"]', @).first().val o.term
			$('select[name="default_class"]', @).first().val(o.default_class).selectmenu 'refresh'

		###
		# If there are other plugins publishing on the same channel,
		# subscribing to the channel will update this search object.
		.subscribe 'search', (o) ->
			for x in $(':input', @)
				n = x.name
				switch n
					when 'search', 'offset', 'visibility_limit' then continue
					when 'item_type' then o.item_type ?= o.item_type.join ''
				$(x).val o[n] if o[n]
			$('select', @).each -> $(@).selectmenu 'refresh'
			$('input[type="checkbox"]', @).each -> $(@).checkboxradio 'refresh'
			return
		###
