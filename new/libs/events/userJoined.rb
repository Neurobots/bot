module Userjoined

	def userJoinedInit

  	self.client.on :user_entered do |user|
    	if @botData['blacklist'].include?(user.id)
      	user.boot('Blacklisted')
    	elsif user.id == client.user.id
      	# No op
    	else
    		self.db.query("insert into bot_ustats_#{MAGICKEY} set userid='#{user.id}', last_seen='#{`date`.chomp}', name='#{self.db.escape_string(user.name)}' on duplicate key update last_seen='#{`date`.chomp}', name='#{self.db.escape_string(user.name)}' ")

    		EventMachine::Timer.new(5) { Turntabler.run { processEvent( user, '#user_entered') } }
    	end

	  end

	end

end
