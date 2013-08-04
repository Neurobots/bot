module Userbooted

	def userBootedInit

 		self.client.on :user_booted do |boot|
    	processEvent( boot.user, "#user_booted" )
    end

  end

end
