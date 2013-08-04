module Songvoted 

	def songVotedInit

  	self.client.on :song_voted do |song|
    	person = song.votes.pop
    	#client.room.say(":song_voted triggered vote counted #{person.user.name} #{person.direction}")
    	processEvent( person.user, "#song_lamed" ) if person.direction == :down
    	processAntiIdle( person.user,0) if (/B/ =~ @botData['flags'])and(@botData['pkg_b_data']['anti_idle'].to_i == 1)
    end

  end

end
