module Eventstraps
	
	def processEvent( user, t_event )
		
		# client.room.say("Processing Event #{t_event}")
  	if user.id != self.client.user.id
    	@botData['events'].each { |event|
      	if event['event'] == t_event
        	if event['delivery_method'].to_i == 1
          	if event['include_name'].to_i == 0
            	self.client.room.say(event['pre_text'] + event['post_text'])
            else
            	self.client.room.say(event['pre_text'] + user.name + event['post_text'])
            end
          else
          	if event['include_name'].to_i == 0
          		user.say(event['pre_text'] + event['post_text'])
            else
            	user.say(event['pre_text'] + user.name + event['post_text'])
            end
          end
        end
      }
    end
  end



	def moderatorAddedInit
  	
		self.client.on :moderator_added do |user|
    	processEvent( client, user, "#moderator_added" )
    end

	end

	def trapEvents
		
		self.moderatorAddedInit
					
	end

end
