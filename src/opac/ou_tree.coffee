# We define a module containing the *ou_tree* jQuery plugin
# to append a list of optional org units to an input selector.
# If an originating library system has been chosen by the query string,
# we will narrow the option list to the system branches.

define ['eg/eg_api'], (eg) -> (($) ->

	# We define a default configuration for the plugin.
	defaults =
		# What is the property name of the selector container?
		name: 'org_unit'
		# Should ou nodes which cannot have users also be listed as options?
		all: true
		# What is the indicator for each level of indention?
		indent: '. '
		# Which option is the selected default?
		# If a number, then the option element with that value will be selected by default.
		# If a string, then the first option will be the default element and will be renamed with the string.
		# If null, then first option will be default and will not be renamed.
		selected: 0
		# Should the selector have focus?
		focus: false

	OU_tree = {}
	OU_tree_desc = {}
	OU_types = {}

	# Convert an org unit ID to its short name or an empty string
	id_name = (ou_id) -> OU_tree[ou_id]?.name or ''

	# Convert an org unit short name to an org unit object
	name_ou = (ou_name) ->
		ou_name = ou_name.toUpperCase()
		return ou for id, ou of OU_tree when ou.shortname is ou_name

	# Convert an org unit object to its depth in the org unit tree
	ou_depth = (ou) -> OU_types[ou.ou_type].depth

	# Convert an ol text string into an org unit ID.  The ol value is either
	# already an org unit ID or an org unit shortname.
	# If the ou shortname or ou ID does not exist, return ID 1.
	ol_id = (ol) ->
		unless isNaN (id = Number ol)
			if id_name id then id else 1
		else
			(name_ou ol)?.id or 1

	# Convert an ol text string into an org unit depth.  The ol value is either
	# an org unit ID or an org unit shortname.
	ol_depth = (ol) ->
		unless isNaN (id = Number ol)
			ou_depth OU_tree[id]
		else
			ou_depth name_ou ol


	$.fn.ou_tree = (o) ->

		# We determine the runtime configuration by extending the default by a given options object.
		rc = $.extend {}, defaults, o

		# We will first get the whole ou tree
		# in order to determine which sub-tree the selector should list options for.
		eg.openils 'actor.org_tree.retrieve', (ouTree) =>
			OU_tree = ouTree
			ou_id = ol_id window.query.ol if window.query?.ol?

			# We will make another service call to get the descendant nodes of the sub-tree.
			# We will also get the tree of ou types where depth levels can be determined.
			@parallel 'organization list',
				ouTree:  eg.openils 'actor.org_tree.descendants.retrieve', ou_id
				ouTypes: eg.openils 'actor.org_types.retrieve'
			, (x) ->
				OU_tree_desc = x.ouTree
				OU_types = x.ouTypes

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
				$select = $('<select data-native-menu="false">').prop 'name', rc.name
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
			return
		return @
	return {
		id: ol_id
		id_depth: ol_depth
		id_name: id_name
	}
)(jQuery)
