# Define a placeholder module to require the common modules used across web
# pages. For conveninece, it returns a reference to the settings module
# which contains run-time configurations.

define [
	'settings'
	'json2'
	'jsd'
	'eg/eg_api'
	'plugin'
	'template'
], (settings) -> settings
