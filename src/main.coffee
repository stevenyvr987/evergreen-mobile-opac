require.config
	waitSeconds: 60

	paths:
		jquery: '//ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min'
		jqm:    'lib/jquery.mobile-1.1.0.min'
		json2:  '//ajax.cdnjs.com/ajax/libs/json2/20110223/json2'
		jsd:    'lib/jsdeferred'
		md5:    'lib/md5'
		jqm_sd: 'lib/jquery.mobile.simpledialog2'
		fmall:  'dojo/fieldmapper/fmall'
		fmd:    'eg/fm_datatypes'

	priority: ['jquery', 'base']

require [
	'jquery', 'base'
	'messages2', 'load_spinner', 'login_bar'
], ($) ->

	$ ->
		# We will apply a load spinner to the body.  The load spinner will
		# indicate that data is being transferred across the network.
		$('body').load_spinner()

		# We will apply a message box.  The message box will display error or
		# progress messages.
		$('#messages').messages()

		# We will prepare a container for enabling the user to log in or log out.
		$('#login_bar').login_bar()

		# We will hide account summary lines,
		# because the user is not logged in upon startup.
		$('.account_summary').hide()

		# Upon user login, we will show account summary lines.
		$('#account_summary').subscribe 'session.login', ->
			$('.account_summary', @).show()
			# We will also load and apply the account summary plugin
			# if it hasn't been applied before.
			require ['account/summary'], => @acct_summary()
			return false

		# Upon starting an OPAC search for first time, we will load and apply
		# the opac search page.
		$('#opac_search').one 'click', ->
			require ['opac/search'], => $(@).opac_search()
			return # need to bubble up click event for jQM

		# Whenever the user expands the search bar,
		# my account summary bars should collapse, and vice versa.
		# This means the search bar acts as part of the collapsible set of summary bars,
		# even though it is not located inside the container
		# that defines the summary bars as a collapsible set.
		toggle = if $(@).is(':visible') then 'collapse' else 'expand'
		$('.account_summary').click ->
			$('#opac_search').trigger toggle
			return # need to bubble up click event for jQM
		$('#opac_search').click ->
			$('.account_summary').each -> $(@).trigger toggle
			return # need to bubble up click event for jQM

		# Upon showing a page, we focus on a specific element that depends on
		# the context.
		$.fn.collapsed = -> @closest('.ui-collapsible').is('.ui-collapsible-collapsed')
		$('body').on 'pageshow', (e) ->
			t = e.target
			switch t.id
				when 'login_window' then $('form input:eq(0)', t).focus()
				when 'edit_hold' then $('a.reset', t).focus()
				when 'main'
					$sb = $('#search_bar')
					$('form input:eq(0)', $sb).focus() unless $sb.collapsed()
					$sr = $('#search_result')
					$('a.title:eq(0)', $sr).focus() unless $sr.collapsed()

		# Uncover the pages that were invisibile during the initial loading phase
		$('div[data-role="page"]').css(visibility: 'visible')

		# Do not show again the default message that was shown during initial loading
		$('#messages').empty()
		return
