module Songended

	def songEndedInit

    self.client.on :song_ended do |song|
    	if song.played_by != self.client.user
				votes_up = 0
				votes_down = 0
				# There is a horrible bug here.  song votes each isn't populated every time and trying to calculate it ourselves isn't working either which means it's not getting saved to ustats right at all
			  # I think this is an api bug but i'm not sure yet.  I"m checking in the temp fix for it now
				song.votes.each do |vote|
					votes_up += 1 if vote.direction == :up
					votes_down += 1 if vote.direction == :down
				end
    		self.db.query("update bot_sstats_#{MAGICKEY} set times_awesomed=times_awesomed+#{song.votes_count_up}, times_lamed=times_lamed+#{song.votes_count_down} where songid='#{digest(song.title, song.artist)}'")
    		self.client.room.say("#{song.title}") if @botData['stats']
    		self.client.room.say("Round:[ #{votes_up} :thumbsup:  ][ #{votes_down} :thumbsdown:  ][ #{@snagged} <3  ]") if @botData['stats']
    		@snagged=0

    		self.db.query("select times_awesomed, times_lamed, times_snagged, times_played from bot_sstats_#{MAGICKEY} where songid='#{digest(song.title, song.artist)}' limit 1").each do |lsong|
      		self.client.room.say("Life:[ #{lsong[0]} :thumbsup:  ][ #{lsong[1]} :thumbsdown:  ][ #{lsong[2]} <3  ][ #{lsong[3]} :dvd:  ]") if @botData['stats']
     		end
   		 	song.votes.each do |vote|
      		self.db.query("update bot_ustats_#{MAGICKEY} set songs_awesomed=songs_awesomed+1 where userid='#{vote.user.id}'") if vote.direction == :up
      		self.db.query("update bot_ustats_#{MAGICKEY} set songs_lamed=songs_lamed+1 where userid='#{vote.user.id}'") if vote.direction == :down
      	end
    	end

    	@queue.push(song.played_by) if (@queue.count > 0)&&(@botData['autoReQueue'])


    	if @botData['slide'] && self.client.room.djs.count > 3
      	if self.client.room.djs.first == song.played_by
        	self.client.room.say("Thank you \@#{song.played_by.name}, could you please slide for us? (Auto remove in 20 seconds)")
        	dj_to_boot = song.played_by
        	EventMachine::Timer.new(20) do
          	Turntabler.run {
          		if self.client.room.djs.first == dj_to_boot
              	self.client.room.say("Removing #{dj_to_boot.name}")
              	dj_to_boot.remove_as_dj
              end
          	}
        	end
      	end
    	end
  	end

	end

end
