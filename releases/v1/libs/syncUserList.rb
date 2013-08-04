module Syncuserlist

  def syncUserList
    self.client.room.listeners.each do |user|
      self.db.query("insert into bot_ustats_#{MAGICKEY} set userid='#{user.id}', last_seen='#{`date`.chomp}', name='#{self.db.escape_string(user.name)}' on duplicate key update last_seen='#{`date`.chomp}', name='#{self.db.escape_string(user.name)}'")
    end
  end


end
