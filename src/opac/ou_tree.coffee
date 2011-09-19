module 'opac.ou_tree', imports(
	'eg.fieldmapper'
	'eg.eg_api'
), (fm, eg) ->

	# Append a list of optional org units to a selector.
	#
	# 1st argument: if true all ou nodes are selectable;
	# if false, only ou nodes which can have users are selectable.
	#
	# 2nd argument: if a number, then the option element with that value is selected by default;
	# if a string, then first option is the default element and is renamed with the string.
	# If 2nd arg is null, then first option is default and is not renamed.

	defaults = {
		'name': 'org_unit'
		'all': true
		'selected': 0
		'indent': '. '
		'focus': false
	}

	$.fn.ou_tree = (o) ->

		# What is the runtime configuration?
		rc = $.extend {}, defaults, o

		eg.openils 'actor.org_tree.retrieve', (ouLookup) =>

			# If an originating library system has been chosen by query string,
			# then we narrow the ou selector to the system branches.
			if window.query?.ol?
				ol = window.query.ol.toUpperCase()
				for id, ou of ouLookup when ou.shortname is ol
					thisisit = Number id
					break

			@parallel 'organization list',
				ouTypes: eg.openils 'actor.org_types.retrieve'
				ouTree:  eg.openils 'actor.org_tree.descendants.retrieve', thisisit
			, (x) ->
				# We use data-native-menu for this selector because it has many options
				# and jQM's version would display options menu in a dialog,
				# but there is a problem with it when combined with another dialog.
				#$select = $('<select data-native-menu="false">').prop 'name', rc.name
				$select = $('<select>').prop 'name', rc.name

				# What are the select options based on the flattened ou tree?
				options = []
				for ou_id, ou of x.ouTree

					# ou_name is indented for each depth level,
					# ie, '. NameAtDepth1', '. . NameAtDepth2'
					ou_name = []
					ou_type = type = x.ouTypes[ou.ou_type]
					while type
						break if type.id is 1
						ou_name.push rc.indent
						type = x.ouTypes[type.parent]
					# Join ou_name to its indentation markers,
					ou_name.push ou.name
					ou_name = ou_name.join('')

					# Either all ou nodes or only ou nodes which can have users
					# are turned into selectable option values.
					option = "<option value=\"#{ou_id}\">"
					if rc.all
						options.push $(option).text ou_name
					else if not ou_type.can_have_users or ou_type.can_have_users is 'f'
						options.push $('<optgroup>').prop 'label', ou_name
					else
						options.push $(option).text ou_name

				# Build select menu options.
				$select.append x for x in options

				# What is the default option value?
				if rc.selected
					if isNaN rc.selected
						$select.children().first().text rc.selected
					else
						$select.children().each ->
							if Number($(@).val()) is rc.selected
								$(@).prop 'selected', 'selected'
								return false

				# Focus on selector if asked for.
				$select.focus() if rc.focus

				@append $select
				$select.parent().trigger 'create'

		return @
