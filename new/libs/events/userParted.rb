module Userparted

	def userPartedInit

    self.client.on :user_left do |user|
    self.db.query("update  bot_ustats_#{MAGICKEY} set last_seen='#{`date`.chomp}' where userid='#{user.id}'")
    processEvent( user, "#user_left" )
    if @queue.include?(user)
      EventMachine::Timer.new(20) do
        Turntabler.run { @queue.delete(user) if !self.client.room.listeners.include?(user) }
        end
      end
    end
		
  end

end
