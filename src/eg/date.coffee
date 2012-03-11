# date.coffee
#
# A module providing convenience functions for the Date class.

define ->

	now: -> new Date().getTime()

	year: -> new Date().getFullYear()

	current: ->

		zero_pad = (num) ->
			# Taken from date.js, MIT/GPL
			s = '0' + num
			s.substring s.length - 2

		date = new Date()
		date.getFullYear() + '-' + zero_pad(date.getMonth() + 1) + '-' + date.getDate()

