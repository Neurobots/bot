module Djadded

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
	

end
