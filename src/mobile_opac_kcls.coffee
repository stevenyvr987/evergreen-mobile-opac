# mobile_opac.coffee
#
# Entry way to the mobile OPAC application.


Deferred.define()

# For debugging: catch errors thrown by Deferred callbacks and show them as alert messages.
#Deferred.onerror = (e) -> alert e + "\n" + JSON.stringify e, null, '  '

jMod.config { path: 'js' }

# Customize layout and behaviour of jQuery.blockUI plugin.
jQuery.extend $.blockUI.defaults,
	message: "Error. Reload the page."
	applyPlatformOpacityRules: false
# Styles for jQuery.blockUI are defined in CSS files.
jQuery.blockUI.defaults.css = {}
jQuery.blockUI.defaults.overlayCSS = {}
jQuery.blockUI.defaults.overlayCSS.opacity = 0.6
jQuery.blockUI.defaults.overlayCSS['-ms-filter'] = 'progid:DXImageTransform.Microsoft.Alpha(Opacity=60)'
jQuery.blockUI.defaults.overlayCSS.filter = 'alpha(opacity=60)'
jQuery.blockUI.defaults.growlCSS.opacity = 0.9
jQuery.blockUI.defaults.growlCSS['-ms-filter'] = 'progid:DXImageTransform.Microsoft.Alpha(Opacity=90)'
jQuery.blockUI.defaults.growlCSS.filter = 'alpha(opacity=90)'
# FIXME: if external growlCSS is used, we get layout problem.
#jQuery.blockUI.defaults.growlCSS = {}

# FIXME: Dependents of eg.fieldmapper, but we need to load early.
jMod.include 'dojo.fieldmapper.fmall', 'eg.fm_datatypes'

# Do a one-time parse of any parameters in the query string.
# Make it available in window.query object.
( (q) ->
	return unless q.length
	query = {}
	d = (x) -> decodeURIComponent x.replace /\+/g, ' '
	r = /([^&=]+)=?([^&]*)/g
	while x = r.exec q
		query[d x[1]] = d x[2]
	window['query'] = query
)(window.location.search.substring(1))


module 'mobile_opac', imports(
	'messages'
	'load_spinner'
	'login_bar'
), ->

	kcls_search_bar_settings =
		facets:
			'' : 'All Item Types'
			'a': 'BOOK'
			'b': 'MAGAZINE'
			'c': 'PRINTED MUSIC'
			'd': 'MICROFORM'
			'f': 'FILMS'
			'g': 'VIDEO'
			'h': 'DVD'
			'i': 'BOOK ON CASSETTE'
			'j': 'MUSIC CD'
			'k': 'MUSIC CASSETTE'
			'l': 'MUSIC LP'
			'm': 'SOFTWARE'
			'n': 'BOOK ON CD'
			'o': 'KIT'
			'p': 'NEWSPAPER'
			'q': 'LARGE PRINT'
			'r': '3-D OBJECT'
			's': 'SLIDE SET'
			't': 'ONLINE'
			'u': 'PLAYER'
			'v': 'EBOOK - TEXT'
			'w': 'EBOOK - AUDIO'
			'x': 'DOWNLOAD MUSIC'
			'y': 'DOWNLOAD VIDEO'
			'e': 'EQUIPMENT'
			'z': 'MAP'
			'2': 'CASSETTE + BOOK'
			'5': 'CD + BOOK'
		language:
			'' : 'All Languages'
			ara: 'Arabic'
			arm: 'Armenian'
			chi: 'Chinese'
			scr: 'Croatian'
			eng: 'English'
			fre: 'French'
			ger: 'German'
			heb: 'Hebrew'
			hin: 'Hindi'
			ita: 'Italian'
			jpn: 'Japanese'
			khm: 'Khmer'
			kor: 'Korean'
			pan: 'Panjabi'
			per: 'Persian'
			pol: 'Polish'
			por: 'Portuguese'
			rus: 'Russian'
			scc: 'Serbian'
			som: 'Somali'
			spa: 'Spanish'
			tal: 'Tagalog'
			tam: 'Tamil'
			tha: 'Thai'
			ukr: 'Ukranian'
			vie: 'Vietnamese'

	jQuery ($) ->

		# Implement an accordion behaviour.
		$('.accordion').click ->
			# First, hide all panes.
			$('.accordion').next().slideUp 'fast'
			# Then, reveal this pane only
			if ($pane = $(@).next()).is ':hidden'
				if $link = $(@).children 'span.link'
					$pane.slideDown('slow')
					# and refresh plugins contained within.
					.children('.plugin').andSelf().refresh()
					# Also, refresh the link content.
					# By convention, the link id is the data channel name.
					$link.publish $link.attr 'id'
			return false
		.next().hide() # Initially hide all panes.

		# Upon starting an OPAC search, dynamically load search bar and result summary plugins.
		$('#opac_search').one 'click', ->
			thunk imports('opac.search_bar'), -> $('#search_bar').search_bar kcls_search_bar_settings
			thunk imports('opac.search_result'), -> $('#result_summary').result_summary()
			return # Allow click event to bubble up to accordion link.

		# Upon user login, dynamically load account summary plugin.
		$('#account_summary').subscribe 'login_event', ->
			thunk imports('account.summary'), => @acct_summary() unless @plugin()
			return false

		# The following interactive panes rely on jQuery.blockUI.
		$('#messages').messages()    # Displays error messages and notices.
		$('#loading').load_spinner() # Indicates data loading is occurring between client and server.
		$('#login_bar').login_bar()  # Enables user to log in and out; indicates status of session.
		return
