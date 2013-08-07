module Processautobop

	def processAutoBop( person )
	if (@autobop_count == 3)
		self.client.room.current_song.vote	
	else
		@autobop_count++
	end

end
