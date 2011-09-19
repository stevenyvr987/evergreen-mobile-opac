# sort.coffee
#
# A plugin that lets you choose the sort order of a search. The preferences
# can be retrieved from the <select> elements the plugin creates. They have the
# correct names to be used as parameters of a search object.

module 'opac.sort', imports('plugin'), ->

	# Caution: names and values of selectors must match
	# parameter names and values of an Evergreen search query.
	defaults = {
		sort: {
			'':      'Sort by relevance'
			pubdate: 'Sort by publication date'
			title:   'Sort by title'
			author:  'Sort by author'
		}
		sort_dir: {
			desc: 'c, b, a / 3, 2, 1'
			asc:  'a, b, c / 1, 2, 3'
		}
	}


	# Build a set of selectors and their options specified by input object.
	$.fn.build_selectors = (o) ->

		# Append select elements.
		@append $("<select name=#{n} />") for n of o

		# Append option elements for each selector.
		for x in @find('select') when options = o[$(x).prop 'name']
			$(x).append "<option value=#{v}>#{n}</option>" for v, n of options

		return @


	$.fn.sort_chooser = (options) ->

		@plugin('sort')

		# Build a pair of selectors.
		.build_selectors($.extend {}, defaults, options)

		# Add change behaviour to selector pair.
		.find('select').first().change ->
			if $(@).val() is ''
				$(@).next().prop('disabled', true).val('asc')
			else
				$(@).next().prop('disabled', false)
			return false

		# Add initial default behaviour.
		#.next().prop 'disabled', true

		return @
