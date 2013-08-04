module Userinput

	def userInputInit

		self.client.on :user_spoke do |message|
    	if message.sender.id != self.client.user.id
      	processTriggers( message )
      	processPkgB( message, 0 ) if /B/ =~ @botData['flags']
      	processAntiIdle( message.sender, 0 ) if (/B/ =~ @botData['flags']) and (@botData['pkg_b_data']['anti_idle'].to_i == 1)
    	end
    end
 
		self.client.on :message_received do |message|
    	processTriggers( message )
    	processPkgB( message, 1 ) if /B/ =~ @botData['flags']
    end

  end

end
