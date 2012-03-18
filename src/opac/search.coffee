# We define a custom jQuery plugin to define a search page.  The page consists
# of two interactive areas, a search bar and a result list.  The search bar
# will be customized by values found in _window.settings_.

define [
	'jquery'
	'opac/search_bar'
	'opac/search_result'
	'cover_art'
	'plugin'
], ($) ->
	$.fn.opac_search = ->
		return @ if @plugin()
		@plugin 'opac_search'
		$('#search_bar').search_bar(window.settings)
		$('#result_summary').result_summary().cover_art()
		return @
