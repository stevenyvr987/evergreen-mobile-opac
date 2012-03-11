# We define a module to contain a pair of jQuery plugins to show cover art, one
# to show a thunmbnail version, the other to show a larger version.
define ['jquery'], ($) ->

	# Define the location where large or small versions of jacket cover art can
	# be downloaded keyed on an ISBN
	url = "/opac/extras/ac/jacket"

	# We define a jQuery plugin to show a thumbnail version of a jacket cover.
	# The context is a list element of a jQuery Mobile listview.
	$.fn.thumbnail_art = (isbn) ->
		src = "#{url}/small/#{isbn}"
		img = ($img = $('<img class="cover_art">')).get(0)
		$img
			.load( ->
				# > If we do not get back an image larger than one-by-one
				# pixel, we will remove it.
				$img.remove() unless img.naturalHeight > 1 and img.naturalWidth > 1
				return false
			)
			.prependTo(@)
			# > We will set the src property as the last operation of the
			# chain, because the presence of the src will trigger an HTTP GET.
			.prop('src', src)
		return @

	# We define a jQuery plugin to show a larger version of a jacket cover upon
	# the user clicking a thumbnail image. The image will auto-scale to fit
	# within its container using CSS techniques.
	$.fn.cover_art = ->
		@delegate 'img`', 'click', (e) ->
			src = e.target.src.replace 'small', 'large'
			$img = $('<img class="cover_art">').prop('src', src)
			$page = $('#cover_art')
				.find('.content')
				.empty().append($img)
				.end()
			$.mobile.changePage $page
			$page.refresh
			return false

