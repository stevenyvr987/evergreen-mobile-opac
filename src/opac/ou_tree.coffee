# We define a module containing the *ou_tree* jQuery plugin
# to append a list of optional org units to an input selector.
# If an originating library system has been chosen by the query string,
# we will narrow the option list to the system branches.

define ['jquery', 'eg/eg_api'], ($, eg) ->

	# We define a default configuration for the plugin.
	defaults = {
		# What is the property name of the selector container?
		'name': 'org_unit'
		# Should ou nodes which cannot have users also be listed as options?
		'all': true
		# What is the indicator for each level of indention?
		'indent': '. '
		# Which option is the selected default?
		# If a number, then the option element with that value will be selected by default.
		# If a string, then the first option will be the default element and will be renamed with the string.
		# If null, then first option will be default and will not be renamed.
		'selected': 0
		# Should the selector have focus?
		'focus': false
	}

	$.fn.ou_tree = (o) ->

		# We determine the runtime configuration by extending the default by a given options object.
		rc = $.extend {}, defaults, o

		# We will first get the whole ou tree
		# in order to determine which sub-tree the selector should list options for.
		eg.openils 'actor.org_tree.retrieve', (ouTree) =>
			if window.query?.ol?
				OL = window.query.ol.toUpperCase()
				for ou_id, ou of ouTree when ou.shortname is OL
					ou_id = Number ou_id
					break

			# We will make another service call to get the descendant nodes of the sub-tree.
			# We will also get the tree of ou types where depth levels can be determined.
			@parallel 'organization list',
				ouTree:  eg.openils 'actor.org_tree.descendants.retrieve', ou_id
				ouTypes: eg.openils 'actor.org_types.retrieve'
			, (x) ->
				# Using the ou tree and ou types, we build a list of select options.
				options = []
				for ou in x.ouTree

					# A preliminary step is to build an ou name
					# so that it is indented for each depth level,
					# eg, '. NameAtDepth1', '. . NameAtDepth2',
					# using the default indentation marker.
					ou_name = []
					ou_type = type = x.ouTypes[ou.ou_type]
					while type
						break if type.id is 1
						ou_name.push rc.indent
						type = x.ouTypes[type.parent]
					ou_name.push ou.name
					ou_name = ou_name.join('') # joining ou name to its indentation markers

					# The final step is to build this option element using this
					# ou name as its label and this ou id as its value.
					#
					# If the option element will be a selectable option, we
					# will also convert the ou name into a text node, because
					# some web browsers (eg, Firefox) do not display the label.
					#
					# If the option element will correspond to an ou node that
					# cannot have users and that should not be a selectable
					# option, then it will be converted into an option group
					# with the ou name serving as the label.
					$option = if rc.all
							$('<option>').text ou_name
						else if not ou_type.can_have_users or ou_type.can_have_users is 'f'
							$('<optgroup>')
						else
							$('<option>').text ou_name
					options.push $option.prop
						label: ou_name
						value: ou.id

				# Using the options list, we build a selector.
				$select = $('<select>').prop 'name', rc.name
				$select.append x for x in options

				# For the default option,
				# we will select either the first one or one that is specified.
				if rc.selected
					if isNaN rc.selected
						$select.children().first().text rc.selected
					else
						$select.children().each ->
							if Number($(@).val()) is rc.selected
								$(@).prop 'selected', 'selected'
								return false

				# We will focus on the selector if asked for.
				$select.focus() if rc.focus

				# We append the selector to this container and trigger the parent jQuery Mobile page.
				@append $select
				$select.parent().trigger 'create'

		return @
