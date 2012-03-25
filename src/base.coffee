# Define a placeholder module to require the common modules used across web
# pages.

define [
	'settings'
	'json2'
	'jsd'
	'plugin'
	'template'
], (rc) ->
	# We will prepare Google Analytics tracking if an account ID is specified.
	require(['jquery_ga'], -> $.ga rc.ga_uid) if rc.ga_uid?
	return
