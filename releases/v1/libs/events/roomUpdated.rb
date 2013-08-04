module Roomupdated

	def roomUpdatedInit

		self.client.on :room_updated do |room|
    	@botData['events'].each { |event| self.client.room.say(event['pre_text'] + event['post_text']) if event['event'] == "#room_updated" }
    end

  end


end
