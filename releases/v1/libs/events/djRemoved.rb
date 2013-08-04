module Djremoved

  def djRemovedInit

  self.client.on :dj_removed do |user|
  	processEvent( user,  "#dj_removed" )
    PorocessAntiIdle(user,0) if /B/ =~ @botData['flags'] and (@botData['pkg_b_data']['anti_idle'].to_i == 1)
    @tabledjs.delete(user) if @tabledjs.include?(user)
    if (!@running)&&(!@queue.empty?)
      @running = true
      @called_dj = @queue.shift
      @tabledjs.push(@called_dj)
      self.client.room.say("Ok \@#{@called_dj.name}, you have 30 seconds to get to the stage")
      timer_handle = EventMachine.add_periodic_timer(30) do
        Turntabler.run {
          if self.client.room.djs.include?(@called_dj)
            @running = false
            timer_handle.cancel
          else
            self.client.room.say("\@#{@called_dj.name} you took too long!")
            @tabledjs.delete(@called_dj)
            if !@queue.empty?
              @called_dj = @queue.shift
              @tabledjs.push(@called_dj)
              self.client.room.say("Ok \@#{@called_dj.name}, you have 30 seconds to get to the stage")
            else
              self.client.room.say("Nobody left in the queue!")
              @running = false
              timer_handle.cancel
            end
          end

        }
        end
      end
    end

  end

end
