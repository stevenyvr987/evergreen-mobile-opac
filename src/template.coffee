# jmod template method
#
# 'Borrowed' from underscore.js

module 'template', ->

	# By default, Underscore uses ERB-style template delimiters, change the
	# following template settings to use alternative delimiters.
	c = {
		start:       '<%'
		end:         '%>'
		interpolate: /<%=(.+?)%>/g
	}

	# Quick regexp-escaping function, because JS doesn't have RegExp.escape().
	escapeRegExp = (s) -> s.replace /([.*+?^${}()|[\]\/\\])/g, '\\$1'

	endMatch = new RegExp "'(?=[^"+c.end.substr(0, 1)+"]*"+escapeRegExp(c.end)+")", "g"

	# JavaScript templating a-la ERB, pilfered from John Resig's
	# "Secrets of the JavaScript Ninja", page 83.
	# Single-quote fix from Rick Strahl's version.
	# With alterations for arbitrary delimiters.
	this.template = (str, data) ->

		x = str.replace(/[\r\t\n]/g, " ")
			.replace(endMatch, "\t")
			.split("'").join("\\'")
			.split("\t").join("'")
			.replace(c.interpolate, "',$1,'")
			.split(c.start).join("');")
			.split(c.end).join("p.push('")

		x = "var p=[],print=function(){p.push.apply(p,arguments);};with(obj){p.push('$x');}return p.join('');"
		fn = new Function 'obj', x
		if data then fn data else fn

	return
