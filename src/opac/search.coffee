# We define a custom jQuery plugin to define a search page.  The page consists
# of two interactive areas, a search bar and a result list.  The search bar
# will be customized by values found in the _settings_ module.

define [
	'jquery'
	'settings'
	'opac/search_bar'
	'opac/search_result'
	'opac/cover_art'
	'plugin'
], ($, rc) ->
	$.fn.opac_search = ->
		return @ if @plugin()
		@plugin 'opac_search'
		$('#search_bar').search_bar(rc.settings)
		$('#result_summary').result_summary().cover_art()
		return @
