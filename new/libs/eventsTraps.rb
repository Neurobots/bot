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

  def djAddedInit

  	self.client.on :dj_added do |user|
    	@call_user = 0 if @called_user = user
    	processEvent( user, "#dj_added" )
    	processAntiIdle(user,0) if (/B/ =~ @botData['flags']) and (@botData['pkg_b_data']['anti_idle'].to_i == 1)
    	if ( @queue.count > 0 ) && ( !@tabledjs.include?(user) ) && @botData['queue']
      	client.room.say("I'm sorry \@#{user.name}, but it isn't your turn yet.  People are waiting in the queue to play")
      	user.remove_as_dj
      	@dont_run_spooler = true
    	elsif ( @queue.count == 0 ) && @botData['queue']
      	@tabledjs.push(user)
    	end
    end
	end

	def trapEvents
		
		moderatorAddedInit
		djAddedInit			

	end

end
