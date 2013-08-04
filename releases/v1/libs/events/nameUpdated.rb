module Nameupdated

	def nameUpdatedInit

		self.client.on :user_name_updated do |user|
    	self.db.query("update bot_ustats_#{MAGICKEY} set name='#{self.db.escape_string(user.name)}' where userid='#{user.id}'")
    end

  end

end
