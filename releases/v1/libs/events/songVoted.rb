module Songvoted 

	def songVotedInit

  	self.client.on :song_voted do |song|
    	person = song.votes.pop
    	#client.room.say(":song_voted triggered vote counted #{person.user.name} #{person.direction}")
			processAutoBop( person.user ) if (person.direction == :up)and(@botData['autobop'] == true)
    	processEvent( person.user, "#song_lamed" ) if person.direction == :down
    	processAntiIdle( person.user,0) if (/B/ =~ @botData['flags'])and(@botData['pkg_b_data']['anti_idle'].to_i == 1)
    end

  end

end
