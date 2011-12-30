# We define a module called *search\_bar*
# to contain a jQuery plugin that will enable the user
# to initiate a search of the public catalogue.
# The main content in the search bar is an interactive form
# that can be flipped between basic or advanced mode.
# The plugin will rely on the *ou\_tree* plugin
# to provide interactive behaviour for an ou tree selector.
# The plugin itself will behave as follows. 
#
# * Respond to submit and cancel events from the user
# * Communicate to other plugins using a two-way data channel called *search*
# * Publish an object representing the form input values upon the user submitting the form
# * Receive an object and modify the search form accordingly

module 'opac.search_bar', imports(
	'eg.eg_api'
	'plugin'
	'opac.ou_tree'
), (eg) ->

	# ***
	# Define the search form.
	# The form contains input and selector elements that are named after request parameters.
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


	# ***
	# Define default settings for search bar selectors that are not dynamically built.
	# >FIXME: item_type names are displayed in the search form,
	# but in the result list, a different set of names is used; confusing.
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


	# ***
	# Define a function to build the option list for a selector on the search form.
	settings = {}
	build_options = ->
		# * The build is skipped if there is a predefined options list.
		return if $('option', @).length
		# * Any options list is specified in the *settings* object by selector name.
		$sor = $(@)
		for v, n of settings[ $sor.prop 'name' ]
			$sor.append $("<option value=\"#{v}\">#{n}</option>")
		# * If there is one, the first entry becomes the selected option.
		# Otherwise, the selector is removed.
		$options = $('option', @)
		if $options.length
			$options.first().prop 'selected', 'selected'
		else
			$sor.remove()
		return


	# ***
	# Define a function to reset the visible input elements of the search form
	# that are not automatically taken care of by the browser upon a reset event.
	# This is a lot of fiddly work;
	# it might be better to destroy the form and rebuild it.
	reset_search_form = ->
		$form = $('form', @)
		# * Empty search inputs, visible or not
		$('input[name="term"]', $form).val ''
		# * Uncheck visible checkboxes
		$('input[type=checkbox]:visible:checked', $form)
			.prop('checked', false)
			.checkboxradio 'refresh'
		# * Set visible select menus to their default values
		for s in $('select:visible', $form)
			$s = $(s)
			$s.val $('option:first', $s).val()
			# * Refresh the jQM version of the select menu unless it is part of a set that is not jQM'ed
			$s.selectmenu 'refresh' unless $s.closest('.advanced.search.row').length
		# * Hide the visible year end elements
		$('.year_end:visible', $form).hide()
		# * Publish the event to other interested plugins
		$(@).publish 'clear_data'
		return


	# ***
	# Define a function to flip between different modes of the search form
	flip_to = (mode) ->
		if mode is 'advanced'
			$('.advanced', @).show()
			$('.basic', @).hide()
		else
			$('.basic', @).show()
			$('.advanced', @).hide()

		$('input[name=term]', @).first().focus()
		reset_search_form.call @
		return false


	# ***
	# Define the search bar plugin
	$.fn.search_bar = (options) ->
		@plugin('basic_search search_bar').empty()

		# We determine the runtime settings by extending the default by a given options object.
		settings = $.extend {}, defaults, options

		# We create the search form.
		$form = $(search_form)
		# We build the ou selector, defaulting the scope to the top of the ou tree.
		$('.org_unit_selector', $form).ou_tree
			'all': true
			'selected': if window.query?.ol? then null else 'All Libraries'
			'indent': '_ '
		# We build option lists for the other selectors.
		$('select', $form).each -> build_options.call @
		# Initially, we show the 'basic' search form.
		flip_to.call $form, 'basic'
		# But we hide the year end elements.
		$('.year_end', $form).hide()
		@append($form).trigger('create')

		# Upon a change in the flip switch,
		# we will flip between basic and advanced modes of the search form.
		.delegate '.search.type', 'change', (e) =>
			flip_to.call @, $(e.target).val()

		# Upon the user clicking the buttons to add or delete search rows
		.delegate 'button.add', 'click', (e) =>
			$p = $(e.target).closest 'fieldset'
			$p.after $p.clone true
			@find('select', $p).each -> build_options.call @
			return false
		.delegate 'button.delete', 'click', (e) =>
			$p = $(e.target).closest 'fieldset'
			$n = $('div.advanced fieldset.search.row', @)
			$p.remove() unless $n.length is 1
			return false

		# Upon the user clicking the publish year end input,
		# we will show or hide the text box for year end depending on verb chosen by user.
		.delegate 'input[name=pub_year_verb]', 'click', (e) =>
			between = $(e.target).val() is 'between'
			$yr_end = $('.year_end', @)
			if between then $yr_end.show() else $yr_end.hide()
			return

		# Upon the user clicking the reset button or the esc key,
		# we will nullify all input and select values.
		.delegate 'button[type=reset]', 'click', =>
			reset_search_form.call @
		.keyup (e) =>
			switch e.keyCode
				when 27 then $('button[type=reset]', @).click()
			return false

		# Upon the user submitting the search form,
		# we will convert the input values into a data object
		# and publish it on the *search* channel.
		.submit ->
			$this = $(@)

			# We validate that at least one input term contains non-whitespace.
			ok = false
			$('input[name=term]', @).each ->
				if @value
					ok = true
					return false
			return false unless ok

			# After validation, we build an object from the input and select values of the search form.
			# For a property name into an array, eg, name:[1, 2],
			# we cast them into multiple values.
			o = {}
			for x in $this.children('form').serializeArray()
				unless o[x.name]?
					o[x.name] = x.value
				else
					unless $.isArray o[x.name]
						o[x.name] = [o[x.name]]
					o[x.name].push x.value

			# We calculate the search depth from the indentation of the selected ou name.
			o.depth = $('select[name=org_unit]', @).find(':selected').text().match(/\_ /g)?.length or 0

			$this.publish 'search', [o]
			return false

		# Upon receiving a data object on the *search* channel published by other plugins,
		# we will handle it if it corresponds to an author search.
		.subscribe 'search', (o) ->
			return unless o.default_class is 'author'
			# We revert to the basic search form,
			# and modify the search term in the form.
			flip_to.call @, 'basic'
			$('input[name="term"]', @).first().val o.term
			$('select[name="default_class"]', @).first().val(o.default_class).selectmenu 'refresh'

# ***
### Commented out
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
