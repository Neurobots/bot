module Backgroundloop

def backgroundLoopInit
	# We should set 10 to a constant of TICK someday
  EventMachine::PeriodicTimer.new(10) do
    Turntabler.run {

		# These four control autodj and alone dj, they probably should be removed at some point because we are violating the tt TOS ( but I kinda don't care )
    self.client.room.become_dj if (self.client.room.djs.count < 2) && (!self.client.user.dj?) && (@botData['autodj']) && (@botData['alonedj'])
    self.client.room.become_dj if (self.client.room.djs.count < 2) && (!self.client.user.dj?) && (@botData['autodj']) && (!@botData['alonedj']) && (self.client.room.djs.count > 0)
    
		self.client.user.remove_as_dj if (self.client.room.djs.count > 2 ) && (self.client.user.dj?) && (self.client.room.current_dj != self.client.user) && (@botData['autodj'])
    self.client.user.remove_as_dj if (self.client.user.dj?) && ( self.client.room.djs.count == 1 ) && (!@botData['alonedj'])
    
		# Blacklist
		self.client.room.listeners.each do |user|
			# Executioner
      user.boot('Blacklisted') if @botData['blacklist'].include?(user.id)

			# Hard coded klines
			user.boot('Fraud is not ok.') if user.id.match('4e6fda31a3f75112c7085798') # XxX
			user.boot('Fraud is not ok.') if user.id.match('51b3f82caaa5cd4a887fa68e') # kn0x
			user.boot('Fraud is not ok.') if user.id.match('50082468eb35c17eae000104') # xorth
			user.boot('Fraud is not ok.') if user.id.match('50936552eb35c1612a411bd5') # Squibbles 
			user.boot('Fraud is not ok.') if user.id.match('50be1fc1eb35c13a7fdb3093') # Squibbles
			user.boot('Fraud is not ok.') if user.id.match('4e8e172f4fe7d0423300cdb4') # sirSITSalot
			user.boot('Fraud is not ok.') if user.id.match('50085278aaa5cd28ef000104') # freebaseballer
			user.boot('Fraud is not ok.') if user.id.match('5014dff0eb35c1688f00013e') # dwiz
			user.boot('Fraud is not ok.') if user.id.match('4fa1a4aaeb35c12f4e000013') # DJ BallsDryDickWet
			user.boot('Fraud is not ok.') if user.id.match('500b23c3eb35c121c9000084') # bladefist
      end
    }
  end
end

end
