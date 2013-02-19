define ['jquery'], ($) ->

	# Define a private publish/subscribe/unsubscribe mechanism based on jQuery
	# trigger/on/off event methods.
	ps = $({})
	publish     = -> ps.trigger.apply ps, arguments
	subscribe   = -> ps.on     .apply ps, arguments
	unsubscribe = -> ps.off    .apply ps, arguments


	# ### Define a jQuery _publish_ method
	# Use the method to enable custom plugins to publish a given data object
	# for a given topic.  The plugin context indicates the publisher; it is
	# passed into *publish*, along with the topic data, as a *trigger*
	# parameter, all of which will be available to the event handler as an
	# extra parameters.
	$.fn.publish = (topic, data) ->
		#console.log "'#{@.prop 'id'}' publishing data", data, "to topic '#{topic}'"
		publish topic, [@, data]
		return @


	# ### Define a jQuery _subscribe_ method
	# Use the method to subscribe custom plugins for one or more specified
	# topics.  The plugin context indicates the subscriber; it is passed into
	# *subscribe* as an *on" parameter, which will be avaliable to the event
	# handler in event.data.
	$.fn.subscribe = (topics, cb) ->
		#console.log "'#{@.prop 'id'}' subscribing to topics '#{topics}'"
		subscribe topics, @, (e, publisher, data) ->
			pubID = publisher.prop 'id'
			subscriber = e.data
			subID = subscriber.prop 'id'
			# Unless the publisher is the subscriber, define a subscription
			# handler to appliy a given callback function to the subscriber.
			# Otherwise, do not handle the subscription by returning a null
			# event handler.
			unless pubID is subID
				result = cb.apply subscriber, data
				# Refresh the subscriber plugin with the callback result
				# unless it is false.
				subscriber.trigger '_', [result] unless result is false
				#console.log "Subscription handled: '#{pubID}' > '#{subID}', topic '#{topics}', data", data
			else
				#console.log "Subscription not handled: '#{pubID}' > '#{subID}', topic '#{topics}', data", data
		return @


	# ### Define a jQuery _unsubscribe_ method
	$.fn.unsubscribe = (topics) ->
		unsubscribe topics
		return @
