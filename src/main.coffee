require.config
	waitSeconds: 60

	paths:
		json2:  '//ajax.cdnjs.com/ajax/libs/json2/20110223/json2'
		jsd:    'lib/jsdeferred'
		md5:    'lib/md5'
		jqm_sd: 'lib/jquery.mobile.simpledialog2'
		fmall:  'dojo/fieldmapper/fmall'
		fmd:    'eg/fm_datatypes'

require [
	'base'
	'messages2'
	'load_spinner'
	'login_bar'
], -> (($) ->
	
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
		$('.account_summary .ui-collapsible-heading').on 'click', ->
			$('#opac_search').trigger 'collapse'
			return # need to bubble up click event for jQM
		$('#opac_search').on 'click', ->
			$('.account_summary').each -> $(@).trigger 'collapse'
			return # need to bubble up click event for jQM

		# Upon showing a page, we focus on a specific element that depends on
		# the context.
		$.fn.collapsed = -> @closest('.ui-collapsible').is('.ui-collapsible-collapsed')
		$('body').on 'pageshow', (e) ->
			t = e.target
			switch t.id
				when 'login_window' then $('form input:eq(0)', t).focus()
# FIXME: the rest of the focussing logic is flawed
# if the search bar is displayed or redisplayed, the search term input should
# be focussed.  If there is a list of results shown, the first result should be
# focussed.
#				when 'main'
#					unless ($sb = $('#search_bar')).collapsed()
#						$('form input:eq(0)', $sb).focus()
#					unless ($sr = $('#search_result')).collapsed()
#						$('a.title:eq(0)', $sr).focus()
			return

		# Uncover the pages that were invisibile during the initial loading phase
		$('div[data-role="page"]').css(visibility: 'visible')

		# Do not show again the default message that was shown during initial loading
		$('#startup').empty()
		return
)(jQuery)
