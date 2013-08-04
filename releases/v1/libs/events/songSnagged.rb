module Songsnagged

	def songSnaggedInit

	  self.client.on :song_snagged do |snag|
    	self.db.query("update bot_ustats_#{MAGICKEY} set songs_snagged=songs_snagged+1 where userid='#{snag.user.id}'")
    	self.db.query("update bot_ustats_#{MAGICKEY} set songs_shared=songs_shared+1 where userid='#{self.client.room.current_dj.id}'")
    	self.db.query("update bot_sstats_#{MAGICKEY} set times_snagged=times_snagged+1 where songid='#{digest(snag.song.title, snag.song.artist)}'")
    	processEvent( snag.user, "#song_snagged" )
    	@snagged+=1
    	processAntiIdle( snag.user, 0 ) if (/B/ =~ @botData['flags']) and (@botData['pkg_b_data']['anti_idle'].to_i == 1)
    end

  end

end
