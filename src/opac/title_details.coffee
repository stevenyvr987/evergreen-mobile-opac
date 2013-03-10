# Define a custom jQuery plugin to show details of a title.

define [
	'template'
	'eg/eg_api'
	'plugin'
], (_) -> (($) ->

	$.fn.title_details = (title_id, $img) ->

		list = '''
		<div data-role="collapsible" data-collapsed="false" data-inset="false">
			<h3>Title Details</h3>
			<ul data-role="listview" data-inset="false"></ul>
		</div>
		'''

		# We will format title details as a jQuery Mobile list view of one list element.
		tpl_content = _.template '''
		<li id="title_id_<%= title_id %>">
			<div class="info_box">
				<div>Title:                <span class="value"><%= b.title            %></span></div>
				<div>Author:               <span class="value"><%= b.author           %></span></div>
				<div>Publisher:            <span class="value"><%= b.publisher        %></span></div>
				<div>Call Number:          <span class="value"><%= b.callnumber       %></span></div>
				<div>ISBN:                 <span class="value"><%= b.isbn             %></span></div>
				<div>ISSN:                 <span class="value"><%= b.issn             %></span></div>
				<div>UPC:                  <span class="value"><%= b.upc              %></span></div>
				<div>Publisher Number:     <span class="value"><%= b.publisher_number %></span></div>
				<div>Physical Description: <span class="value"><%= b.phy_descr        %></span></div>
				<div>Edition:              <span class="value"><%= b.edition          %></span></div>
				<div>Frequency:            <span class="value"><%= b.frequency        %></span></div>
				<div>Online Resources: <span class="value"><a href="<%= b.eresource_u %>"><%= b.eresource_z %></a></span></div>
			</div>
		</li>
		'''

		# Define a one-liner to 'pinch' white space out of a jQuery object,
		# ie, remove white space duplicates from inside
		# and trim white space before and after.
		pinch = ($x) -> $.trim $x.text().replace /\s+/g, ' '


		# Define a function to mutate a given MARC text in HTML format to a MARC data object.
		# MARC tags are mapped to text fields according to the *tags2text* object.
		tags2text =
			title:            { '245':'abchp' }
			author:           { '100':'', '110':'', '111':'', '130':'', '700':'', '710':'', '711':'' }
			publisher:        { '260':'' }
			callnumber:       { '092':'', '099':'' }
			isbn:             { '020':'' }
			issn:             { '022':'' }
			upc:              { '024':'' }
			publisher_number: { '028':'' }
			phy_descr:        { '300':'' }
			edition:          { '250':'' }
			frequency:        { '310':'' }
			eresource_u:      { '856':'u' }
			eresource_z:      { '856':'z' }

		marc_text = (html) ->
			marctext = []
			$('.marc_tag_row', html).each ->
				marctext.push pinch($ @).replace(/^(.....)\. /, '$1').replace(/^(...) \. /, '$1')

			# For each specification...
			for name, tags of tags2text
				text = ''
				# For each specified MARC tag...
				for tag, subfields of tags
					# For each text line in MARC record...
					for x in marctext
						continue unless x.match new RegExp "^#{tag}"
						codes = subfields.split ''
						# For each subfield code specified, or for all codes...
						for code in (if codes.length then codes else ['.'])
							code = "\\u2021#{code}(.+?)(?= \\u2021|$)"
							continue unless x2 = x.match new RegExp code, 'g'
							more = (y.replace /^../, '' for y in x2).join ' '
							text = unless text then more else "#{text} #{more}"
					break if text.length
				# We will delete this entry if it has no MARC text.
				if text.length then tags2text[name] = text else delete tags2text[name]
			return tags2text

		# Empty out any previous title details
		@html(list)
		.trigger('create')
		.find('[data-role="listview"]')

		# We try to get the MARC HTML record of a title ID.
		.openils "title details ##{title_id}", 'search.biblio.record.html', title_id, (htmlmarc) ->

			# Upon success, we will fill in the content template with data from the MARC object,
			# and remove the empty parts of the template.
			@html(tpl_content
				title_id: title_id
				b: marc_text htmlmarc
			).find('.value').each ->
				$(@).parent().empty() unless $(@).text()
				# > FIXME: empty divs may be left behind

			# We add the given thumbnail image.
			$img.prependTo $('li', @) if $img.get(0)?.naturalHeight > 0

			@listview 'refresh'
			return
)(jQuery)
