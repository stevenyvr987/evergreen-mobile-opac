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
	defaults =
		refresh: ''
		default_class:
			keyword: 'Keyword'
			title:   'Title'
			author:  'Author'
			subject: 'Subject'
			series:  'Series'
		item_type:
			'': 'All Item Types'
			at: 'Books'
			i:  'Audiobooks'
			g:  'Video Recordings'
			j:  'Music'
			m:  'Electronic Resources'

	# Search form contains input and selector elements that are named after request parameters.
	# FIXME: rename 'type' to 'search_type'; more descriptive.
	# <select name="org_unit" />
	search_form = '''
	<form>
		<div>
			<input  name="term" type="text" />
			<select name="default_class" />
			<select name="item_type" />
			<button type="submit">Search</button>
			<button type="reset">Reset</button>
		</div>
		<span class="org_unit_selector" />
		<div class="sort_chooser" />
		<input name="type" value="advanced" type="hidden" />
		<input name="offset" value="0" type="hidden" />
	</form>
	'''


	$.fn.search_bar = (options) ->
		settings = $.extend {}, defaults, options

		@plugin('basic_search search_bar')
		.html search_form

		# Focus user on the search term input box.
		$('input[name=term]', @).focus()

		# Build selector options.
		@find('select').each ->
			return unless o = settings[ $(@).attr 'name' ]
			$(@).append ('<option value="' + v + '">' + n + '</option>' for v, n of o).join ''

		# Build the ou selector; default selection is the root node.
		$('.org_unit_selector', @).ou_tree {
			'all': true
			'selected': if window.query?.ol? then null else 'Search all libraries'
			'indent': '_ '
		}

		$('.sort_chooser', @).sort_chooser()

		@keyup (e) =>
			switch e.keyCode
				when 27 then $('button[type=reset]', @).click()
			return false

		# Upon reset, nullify all input and select values.
		@delegate 'button[type=reset]', 'click', =>
			$('input[name=term]', @).val ''
			$('select', @).val 0
			$('.sort select', @).change() # FIXME: pokes into sort chooser`
			return false

		@submit ->

			# Build request object from input and select values of search form.
			o = {}
			for x in $(@).children('form').serializeArray()
				o[x.name] = x.value

			# Calculate item type, eg, 'at' becomes ['a', 't']
			o.item_type = o.item_type.split '' if o.item_type?

			# Calculate search depth from indentation of selected ou name.
			o['depth'] = $('select[name=org_unit]', $(@)).find(':selected').text().match(/\_ /g)?.length or 0

			# Publish the search form content on the search data channel.
			$(@).publish 'search', [o]
			return false

		# FIXME: If there are other plugins publishing on the same channel,
		# subscribing to the channel will update this search object.
		# But the plugin will also trigger on its own publishing event,
		# which is unnecessary.
		#
		@subscribe 'search', (o) ->

			@find(':input').each ->
				return if @name is 'search' or @name is 'offset' or @name is 'visibility_limit'
				return unless o[@name]
				o.item_type = o.item_type.join '' if @name is 'item_type'
				$(@).val o[@name]
			@find('.sort select').change() # FIXME: pokes into sort chooser`
			return false
