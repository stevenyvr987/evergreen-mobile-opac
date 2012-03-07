# Define a jQuery method for loading Google Analytics code to track the current
# website.  Loading is done by jQuery's ajax method. It is sufficient to
# specifiy a GA account ID. By default, the _trackPageview method is called.
# Other methods may be specified; see usages below.
#
# Usages:
# $.ga 'UA-12345678-9'
# $.ga 'UA-12345678-9', ['_trackPageview']
# $.ga 'UA-12345678-9', ['_trackPageview', 'url']
# $.ga 'UA-12345678-9', ['_trackPageview', 'url'], ['_trackEvent', 'name', value]

_gaq = []
module 'lib.jquery_ga', ->
	( ($) ->
		$.ga = (uid, commands...) ->
			protocol = if document.location.protocol is 'https:' then 'https://ssl' else 'http://www'
			$.ajax
				type: 'GET'
				url: "#{protocol}.google-analytics.com/ga.js"
				dataType: 'script'
				data: null
				cache: true
				success: ->
					# Add the setAccount command to the command stream
					len = commands.unshift ['_setAccount', uid]
					# Default the command stream to trackPageview if there are no other commands
					commands.push ['_trackPageview'] if len is 1
					_gaq.push commands
					return
	)(jQuery)
