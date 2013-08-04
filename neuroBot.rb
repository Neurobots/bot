#!/usr/bin/env ruby

#	Basic requires needed to make this possible

require 'rubygems'
require 'turntabler'
require 'monitor'
require 'eventmachine'
#require 'em-websocket'
require 'json'
require 'open-uri'
require 'pp'
#require 'ponder'
require 'mysql'
require 'digest/md5'
require 'nokogiri'

$db = Mysql::new("hal", "nirvana_neurobot", "571b7c5a6fe4", "neurobots")

#	This makes the websocket wrapper work correctly ( kill stdout buffering )
$errorcounts = {}
$sayings = []
$stdout.sync = true
$queue = []
$tabledjs = []
$antiIdle = []
$snagged = 0
#	Dynamic Name Generation for IRC
#$ircName = 'nc' + `cat $OPENSHIFT_DATA_DIR/conf/controller_number`.chomp + 'bot' + (ENV['BOTPORT'].to_i - 30000).to_s

#	Without these we don't know who we are

abort "No magic key in envrioment variable" if !ENV.include? 'MAGICKEY' 
abort "No userid in envrioment variable" if !ENV.include? 'BOTUSERID' 

#	Globals are normally bad m'kay, but were doing so much in and out of scope that this makes our world alot easier

$botData = {
		"userid" => ENV['BOTUSERID'],
		"authid" => "",
		"magicKey" => ENV['MAGICKEY'],
		"ownerid" => "",
		"roomid" => "",
		"ads" => [],
		"triggers" => [],
		"blacklist" => [],
		"level3acl" => [],
		"level2acl" => [],
		"level1acl" => [],
		"command_trigger" => "",
		"running_timers" => [],
		"events" => [],
}

#	AJAX Pull data in

def processEvent( client, user, t_event )
#		client.room.say("Processing Event #{t_event}")
                if user.id != client.user.id
                $botData['events'].each { |event|
                        if event['event'] == t_event
                                if event['delivery_method'].to_i == 1
                                        if event['include_name'].to_i == 0
                                                        client.room.say(event['pre_text'] + event['post_text'])
                                                else
                                                        client.room.say(event['pre_text'] + user.name + event['post_text'])
                                                end
                                else
                                       if event['include_name'].to_i == 0
                                                        user.say(event['pre_text'] + event['post_text'])
                                                else
                                                        user.say(event['pre_text'] + user.name + event['post_text'])
                                                end
                                end
                        end
                }
                end
end

def rehash(client, user)
$errorcounts = {}

$jOutput = JSON.parse((URI.parse("http://www.neurobots.net/websockets/pull.php?bot_userid=#{$botData['userid']}&magic_key=#{$botData['magicKey']}")).read)

$antiIdle = []
$botData['authid'] = $jOutput['bot_authid']
$botData['roomid'] = $jOutput['bot_roomid']
$botData['ownerid'] = $jOutput['owner_userid']
$botData['ads'] = $jOutput['adverts']
$botData['triggers'] = $jOutput['triggers']
$jOutput['blacklist'].pop
$botData['blacklist'] = $jOutput['blacklist'].map {|h| h['userid']}
$botData['command_trigger'] = $jOutput['command_trigger']
$botData['events'] = $jOutput['events']
$botData['events'].pop
$botData['triggers'].pop
$botData['ads'].pop
$botData['level1acl'] = []
$botData['level2acl'] = []
$botData['level3acl'] = []
$jOutput['acl'].pop
$jOutput['acl'].each { |acl|
        $botData['level1acl'].push(acl['userid']) if acl['access_level'] == "1"
        $botData['level2acl'].push(acl['userid']) if acl['access_level'] == "2"
        $botData['level3acl'].push(acl['userid']) if acl['access_level'] == "3"
}
$botData['queue'] = false
$botData['slide'] = false
$botData['autodj'] = false
$botData['stats'] = false
$botData['autoReQueue'] = false
$botData['alonedj'] = false
$botData['flags'] = $jOutput['flags']

('B'..'B').each do |pkg|
	$botData['pkg_'+pkg.downcase+'_data'] = $jOutput['pkg_'+pkg.downcase+'_data'][0] if /#{pkg}/ =~ $botData['flags']
	client.room.say("Package B Activated") if /#{pkg}/ =~ $botData['flags']
end

processAntiIdle(client, client.user,0) if (/B/ =~ $botData['flags'])and($botData['pkg_b_data']['anti_idle'].to_i == 1)


$botData['queue'] = true if $jOutput['start_queue'].to_i == 1
$botData['slide'] = true if $jOutput['start_slide'].to_i == 1
$botData['autodj'] = true if $jOutput['start_autodj'].to_i == 1
$botData['stats'] = true if $jOutput['start_stats'] .to_i == 1
$botData['autoReQueue'] = true if $jOutput['switch_autorequeue'] .to_i == 1
$botData['alonedj'] = true if $jOutput['switch_alonedj'] .to_i == 1


$tabledjs = client.room.djs.to_a if $botData['queue']


if $jOutput['mods_to_lvl1'].to_i == 1
	client.room.moderators.each do |mod|
		$botData['level1acl'].push(mod.id)
		end
end

$sayings = []
$db.query("select * from bot_sayings_#{$botData['magicKey']}").each do |row|
        $sayings.push(row[0]);
        end

if user == nil
client.room.say("triggers: #{$botData['triggers'].count} ads: #{$botData['ads'].count} events: #{$botData['events'].count} acls: #{$jOutput['acl'].count} sayings: #{$sayings.count} ") 
else
user.say("triggers: #{$botData['triggers'].count} ads: #{$botData['ads'].count} events: #{$botData['events'].count} acls: #{$jOutput['acl'].count} sayings: #{$sayings.count} ")
end

#	Ad Spooler
	$botData['running_timers'].each { |timer| timer.cancel }
	$botData['running_timers'] =  []
        $botData['ads'].each do |ad|
                timer = EventMachine::PeriodicTimer.new(ad['delay']) do
			Turntabler.run { client.room.say ad['message'] }
                end
		$botData['running_timers'].push(timer)
        end
	rescue JSON::ParserError, SocketError
end

def validate_security(id, level)
	returnset = 0
	case level
		when 0 # Anyone
			returnset = 1
		when 1 # Level 1
			returnset = 1 if($botData['level1acl'].include?(id)||$botData['level2acl'].include?(id)||$botData['level3acl'].include?(id)||$botData['ownerid'] == id)
		when 2 # Level 2
			returnset = 1 if($botData['level2acl'].include?(id)||$botData['level3acl'].include?(id)||$botData['ownerid'] == id) 
		when 3 # Level 3
			returnset = 1 if($botData['level3acl'].include?(id)||$botData['ownerid'] == id)
		when 4 # Owner
			returnset = 1 if ($botData['ownerid'] == id)
		end
	if returnset == 1
		return true
	else
		return false
	end
end

def digest(title, artist)
	return Digest::MD5.hexdigest(title+artist)
end

def trigger_speak( client, trigger, name )
if trigger['use_saying_switch'].to_i == 1
	client.room.say($sayings.sample)	
else
	if trigger['use_name_switch'].to_i == 1
		client.room.say(trigger['pre_name_response']+name+trigger['post_name_response']) if (trigger['pre_name_response'] != "")||(trigger['post_name_response'] != "")
	else
		client.room.say(trigger['pre_name_response']+trigger['post_name_response']) if (trigger['pre_name_response'] != "")||(trigger['post_name_response'] != "")

	end
end
end


def trigger_pm( client, trigger, user )
if trigger['use_saying_switch'].to_i == 1
        user.say($sayings.sample)
else
        if trigger['use_name_switch'].to_i == 1
                user.say(trigger['pre_name_response']+name+trigger['post_name_response']) if (trigger['pre_name_response'] != "")||(trigger['post_name_response'] != "")
        else
                user.say(trigger['pre_name_response']+trigger['post_name_response']) if (trigger['pre_name_response'] != "")||(trigger['post_name_response'] != "")
        end
end
end




def processTriggers(client, message)

		$botData['triggers'].each do |trigger|
			if (( (trigger['use_trigger_switch'].to_i == 1) && (trigger['use_strict_matching'].to_i == 1) && message.content.match("^"+Regexp.escape($botData['command_trigger'])+Regexp.escape(trigger['trigger_phrase'])+"$"))||((trigger['use_trigger_switch'].to_i == 0) && (trigger['use_strict_matching'].to_i == 1) && message.content.match("^"+Regexp.escape(trigger['trigger_phrase'])+"$"))||((trigger['use_trigger_switch'].to_i == 1) && (trigger['use_strict_matching'].to_i == 0) && message.content.match("^"+Regexp.escape($botData['command_trigger'])) && message.content.match(Regexp.escape(trigger['trigger_phrase'])))||( (trigger['use_trigger_switch'].to_i == 0) && (trigger['use_strict_matching'].to_i == 0) && message.content.match(Regexp.escape(trigger['trigger_phrase'])) ))
			# Mark
			# client.room.say("Action Triggered #{trigger['action']}")
		  	# client.room.say("Validate Security says: "+validate_security(message.sender.id, trigger['access_level'].to_i).to_s)	
			if validate_security(message.sender.id, trigger['access_level'].to_i)
			case trigger['action']
				when "*queue_move"
					(from, to) =  message.content.gsub(/^.+#{trigger['trigger_phrase']}/, '').scan(/\d+/)
					if ( from.abs < $queue.count ) && ( to.abs < $queue.count )
						client.room.say("Moving \##{from} to \##{to}")
						$queue.insert(to, $queue.delete_at(from))
					else
						client.room.say("Queue Move failed: Out of Range")
					end
				when "*queue_list"
					if $botData['queue']
						if $queue.count != 0
							$queue.each_with_index do |user, i|
								client.room.say("Queue Slot \##{i} #{user.name}")
							end
						else
							client.room.say("The queue is empty.")
						end
					else
					client.room.say("The queue is not enabled right now.  Fastest finger right now.")
					end
				when "*queue_add"
					if $botData['queue']
						if !$tabledjs.include?(message.sender)
						if $tabledjs.count == 5
						if !$queue.include?(message.sender)
							$queue.push(message.sender)
							client.room.say("Ok #{message.sender.name}, you are #{$queue.count} in the queue")
						else
							client.room.say("I'm sorry #{message.sender.name}, but you are already in the queue")
						end
						else
							client.user.say("There is a free spot, go fot it")
								
						end
						else
							client.room.say("I can't add you to the queue.  You are already djing")
						end
					else
					client.room.say("The queue is not enabled right now.  Fastest finger right now.")
                                        end
				when "*queue_remove"
					if $botData['queue']
						if $queue.include?(message.sender)
							$queue.delete(message.sender)
							client.room.say("Ok #{message.sender.name}, I'm removing you from the queue")
						else
							client.room.say("I'm sorry #{message.sender.name}, but you aren't in the queue right now")
						end
						
					else
                                        client.room.say("The queue is not enabled right now.  Fastest finger right now.")
					end
				when "*slide"
					$botData['slide'] = !$botData['slide']
					client.room.say("Slide is on: #{$botData['slide']}")
				when "*stats"
					$botData['stats'] = !$botData['stats']
					client.room.say("Display round stats: #{$botData['stats']}")
				when "*autodj"
					$botData['autodj'] = !$botData['autodj']
					client.room.say("Auto DJ: #{$botData['autodj']}")
				when "*queue"
					$botData['queue'] = !$botData['queue']
					if $botData['queue']
						$tabledjs = []
						$called_dj = ""
						$running = false
						client.room.djs.each do |dj|
							$tabledjs.push(dj)
							end
					end
					$tabledjs = [] if !$botData['queue']
					client.room.say("Queue is on: #{$botData['queue']}")
				when "*theme"
					tmp_trigger = trigger.clone
					tmp_trigger['pre_name_response'] = "Theme is: " + tmp_trigger['pre_name_response']
					trigger_speak(client, tmp_trigger, message.sender.name)
				when "*themeset"
					theme_input = message.content.gsub(/^.+#{trigger['trigger_phrase']}/, '')
					pre_post = []
					pre_post[0] = ""
					pre_post[1] = ""
					use_name = "0"
					if theme_input.include?('$name')
						#has name
						pre_post = theme_input.split('$name')
						use_name = "1"
						#client.room.say(" Pre:'#{pre_post[0]}' Post: '#{pre_post[1]}'")
					else
						pre_post[0] = theme_input
						pre_post[1] = ''
						#no name
					end
					pre_post[1] = "" if pre_post[1] == nil
					$botData['triggers'].each do |trig|
						if trig['action'] == "*theme"
							trig['use_name_switch'] = use_name
							trig['pre_name_response'] = pre_post[0]
							trig['post_name_response'] = pre_post[1]
							end
						end
					trigger_speak(client, trigger, message.sender.name)
					#client.room.say("Found #{message.content.gsub(/^.+#{trigger['trigger_phrase']}/, '')}")
				when "*voteup"
					# trigger_speak( client, pre, post, name, switch )
					trigger_speak(client, trigger, message.sender.name)
					client.room.current_song.vote
				when "*votedown"
					client.room.current_song.vote(:down)
					trigger_speak(client, trigger, message.sender.name)
				when "*action"
					trigger_speak(client, trigger, message.sender.name)
				when "*actionpm"
                                        trigger_pm(client, trigger, message.sender)
				when "*status"
					message.sender.say("triggers: #{$botData['triggers'].count} ads: #{$botData['ads'].count} events: #{$botData['events'].count} acls: #{$jOutput['acl'].count} sayings: #{$sayings.count}  ")
					message.sender.say("Slide: #{$botData['slide']}  Queue: #{$botData['queue']}  AutoDj: #{$botData['autodj']}  Stats: #{$botData['stats']}")
				when "*restart"
			  		trigger_speak(client, trigger, message.sender.name)
					exit
				when "*rehash"
		    			trigger_speak(client, trigger, message.sender.name)
					rehash(client, message.sender)
				when "*snag"
					client.room.current_song.add( :index => (client.user.playlist.songs).count )
					client.room.current_song.snag
					trigger_speak(client, trigger, message.sender.name)
				when "*nextup"
					client.user.playlist.update
					client.room.say('Next song: '+((client.user.playlist.songs)[0]).title+' by '+((client.user.playlist.songs)[0]).artist)
					client.room.say('Next song: '+((client.user.playlist.songs)[1]).title+' by '+((client.user.playlist.songs)[1]).artist)
				when "*skip"
					if client.room.current_dj == client.user
						client.room.current_song.skip
						client.user.playlist.update
						#(client.user.playlist.songs)[-1].move(0)
						#((client.user.playlist.songs)[0]).move((client.user.playlist.songs).count)
					else
						(client.user.playlist.songs)[0].move(-1)
						#((client.user.playlist.songs)[0]).skip
					end
						client.user.playlist.update
						trigger_speak(client, trigger ,message.sender.name)
				when "*forget"
					if client.room.current_dj == client.user
						client.room.current_song.skip
						client.user.playlist.songs.last.remove
					else
						client.user.playlist.songs.first.remove
					end
					client.user.playlist.update
					trigger_speak(client, trigger, message.sender.name)
				when "*hopup"
					client.room.become_dj
					trigger_speak(client, trigger, message.sender.name)
				when "*hopdown"
					client.user.remove_as_dj
					trigger_speak(client, trigger, message.sender.name)
				when "*userids"
					client.room.listeners.each do |listener|
						message.sender.say("#{listener.name}")
                				message.sender.say("#{listener.id}")
					end
				when "*say"
					client.room.say(message.content.gsub(/^.+#{trigger['trigger_phrase']} /, ''))
				when "*kick"
  				        userid = message.content.match(/(\h+)$/)
					if $botData['ownerid'].match(/#{userid}/)
						client.room.say("I'm sorry, but I can't do that to my owner")
					else
						client.user(userid).boot(trigger['pre_name_response'])
					end
				when "*ban"
                                        userid = message.content.match(/(\h+)$/)
                                        if $botData['ownerid'].match(/#{userid}/)
                                                client.room.say("I'm sorry, but I can't do that to my owner")
                                        else
						URI.parse("http://www.neurobots.net/websockets/blacklistpush.php?magic_key=#{$botData['magicKey']}&target=#{userid}&reason=#{message.sender.id}").read
						$botData['blacklist'].push("#{userid}")
					
						#client.user(userid).boot(trigger['response'])
                                        end
				when "*removedj"
					client.room.current_dj.remove_as_dj
					trigger_speak(client, trigger, message.sender.name)
				when "*fan"
					begin
					client.room.current_dj.become_fan
					trigger_speak(client, trigger ,message.sender.name)
					rescue
					#client.room.say("failtest");
					$errorcounts['fan'] = 1 if $errorcounts['fan'] == nil
					if (trigger['post_command_fail'] == "")
						client.room.say(trigger['pre_command_fail'])
					else
						client.room.say("#{trigger['pre_command_fail']}#{$errorcounts['fan']}#{trigger['post_command_fail']}")
						$errorcounts['fan'] += 1
					end
					end
				end	
			end
			end	
		end
	end

def processPkgB(client, message, loc)
	# Dice  6
	client.room.say("#{message.sender.name} rolled a " + rand(1..6).to_s ) if ( $botData['pkg_b_data']['dice_6_e'] == "1" ) and ( message.content.match(/^#{$botData['pkg_b_data']['dice_6_t']}/)) and ( loc == 0 )
	message.sender.say("#{message.sender.name} rolled a " + rand(1..6).to_s ) if ( $botData['pkg_b_data']['dice_6_e'] == "1" ) and ( message.content.match(/^#{$botData['pkg_b_data']['dice_6_t']}/)) and ( loc == 1 )

	# Dice 20
        client.room.say("#{message.sender.name} rolled a " + rand(1..20).to_s ) if ( $botData['pkg_b_data']['dice_20_e'] == "1" ) and ( message.content.match(/^#{$botData['pkg_b_data']['dice_20_t']}/)) and ( loc == 0 )
        message.sender.say("#{message.sender.name} rolled a " + rand(1..20).to_s ) if ( $botData['pkg_b_data']['dice_20_e'] == "1" ) and ( message.content.match(/^#{$botData['pkg_b_data']['dice_20_t']}/)) and ( loc == 1 )

	# 8ball
	client.room.say( $botData['pkg_b_data']['8ball_'+rand(1..20).to_s] ) if ( $botData['pkg_b_data']['8ball_e'] == "1" ) and ( message.content.match(/^#{$botData['pkg_b_data']['8ball_t']} /)) and ( loc == 0 )
	message.sender.say( $botData['pkg_b_data']['8ball_'+rand(1..20).to_s] ) if ( $botData['pkg_b_data']['8ball_e'] == "1" ) and ( message.content.match(/^#{$botData['pkg_b_data']['8ball_t']} /)) and ( loc == 1 )

	# Weather
	if ( $botData['pkg_b_data']['weather_e'] == "1" ) and ( message.content.match(/^#{$botData['pkg_b_data']['weather_t']} /))
	
		zipCode = message.content.scan(/\d{5}/).shift

		cnn = Nokogiri::HTML(open("http://weather.cnn.com/weather/forecast.jsp?zipCode=#{zipCode}"))
				location = cnn.css('div#cnnWeatherLocationHeader').shift.to_s.match(/\<b>(.*)<\/b>/)[1]
				current_temp = cnn.css('div.cnnWeatherTempCurrent').shift.text.match(/(\d+)/)
				temps = cnn.css('div.cnnWeatherTemp').shift.text
				temp_hi = temps.match(/Hi\s(\d+)/)
				temp_low = temps.match(/Lo\s(\d+)/)

		client.room.say("The weather report for #{location} is Current Temp: #{current_temp} Todays: #{temp_hi} #{temp_low}") if loc == 0
		message.sender.say("The weather report for #{location} is Current Temp: #{current_temp} Todays: #{temp_hi} #{temp_low}") if loc == 1
	end

	#Wikipedia
        if ( $botData['pkg_b_data']['wikipedia_e'] == "1" ) and ( message.content.match(/^#{$botData['pkg_b_data']['wikipedia_t']} /))

                search = message.content.gsub(/^#{$botData['pkg_b_data']['wikipedia_t']} /, "")
	        rsearch = search.gsub(/ /,"_")	
                myuri = "http://en.wikipedia.org/wiki/#{rsearch}"
		wikipedia = Nokogiri::HTML(open(myuri))
		
		result = wikipedia.css('p')[0].text
		
		client.room.say(result)
		client.room.say("#{myuri}")
        end

	#Last.fm
	 if ( $botData['pkg_b_data']['last_fm_e'] == "1" ) and ( message.content.match(/^#{$botData['pkg_b_data']['last_fm_t']} /))

                search = message.content.gsub(/^#{$botData['pkg_b_data']['last_fm_t']} /, "")
                rsearch = search.gsub(/ /,"+")
                myuri = "http://www.last.fm/music/#{rsearch}"
                wikipedia = Nokogiri::HTML(open(myuri))

                result = wikipedia.css('div#wikiAbstract')[0].css('div')[0].text
		pp result
                client.room.say(result)
                client.room.say("#{myuri}")
	end	
	
	#User Lookup
	if ( $botData['pkg_b_data']['user_lookup_e'] == "1" ) and ( message.content.match(/^#{$botData['pkg_b_data']['user_lookup_t']} /))
		search = message.content.gsub(/^#{$botData['pkg_b_data']['user_lookup_t']} /, "")
		$db.query("select * from bot_ustats_#{$botData['magicKey']} where LOWER(name) = LOWER('#{$db.escape_string(search)}')  LIMIT 1").each do |row|
                case  loc
		when 0 	
			client.room.say("#{row[1]}:")
			client.room.say("#{row[2]}")
			client.room.say("[#{row[4]}:thumbsup:][#{row[5]}:thumbsdown:][#{row[6]}<3][#{row[3]}:dvd:]")
			#client.room.say("#{row[0]}")
		when 1
			message.sender.say("#{row[1]}:")
			message.sender.say("#{row[2]}")
			message.sender.say("[#{row[4]}:thumbsup:][#{row[5]}:thumbsdown:][#{row[6]}<3][#{row[3]}:dvd:]")
			message.sender.say("#{row[0]}")
		end
                	#pp row
        	end

	
	end	

	#Horoscope
	if ( $botData['pkg_b_data']['horoscope_e'] == "1" ) 
		 client.room.say "Aries: " + Nokogiri::HTML(open("http://my.horoscope.com/astrology/free-daily-horoscope-aries.html")).css("div.fontdef1").shift.text if message.content.match(/^.aries/)
		 client.room.say "Taurus: " + Nokogiri::HTML(open("http://my.horoscope.com/astrology/free-daily-horoscope-taurus.html")).css("div.fontdef1").shift.text if message.content.match(/^.taurus/)
		 client.room.say "Gemini: " + Nokogiri::HTML(open("http://my.horoscope.com/astrology/free-daily-horoscope-gemini.html")).css("div.fontdef1").shift.text if message.content.match(/^.gemini/)
		 client.room.say "Cancer: " + Nokogiri::HTML(open("http://my.horoscope.com/astrology/free-daily-horoscope-cancer.html")).css("div.fontdef1").shift.text if message.content.match(/^.cancer/)
		 client.room.say "Leo: " + Nokogiri::HTML(open("http://my.horoscope.com/astrology/free-daily-horoscope-leo.html")).css("div.fontdef1").shift.text if message.content.match(/^.leo/)
		 client.room.say "Virgo: " + Nokogiri::HTML(open("http://my.horoscope.com/astrology/free-daily-horoscope-virgo.html")).css("div.fontdef1").shift.text if message.content.match(/^.virgo/)
		 client.room.say "Libra: " + Nokogiri::HTML(open("http://my.horoscope.com/astrology/free-daily-horoscope-libra.html")).css("div.fontdef1").shift.text if message.content.match(/^.libra/)
		 client.room.say "Scorpio: " + Nokogiri::HTML(open("http://my.horoscope.com/astrology/free-daily-horoscope-scorpio.html")).css("div.fontdef1").shift.text if message.content.match(/^.scorpio/)
		 client.room.say "Sagittarius: " + Nokogiri::HTML(open("http://my.horoscope.com/astrology/free-daily-horoscope-sagittarius.html")).css("div.fontdef1").shift.text if message.content.match(/^.sagittarius/)
		 client.room.say "Capricorn: " + Nokogiri::HTML(open("http://my.horoscope.com/astrology/free-daily-horoscope-capricorn.html")).css("div.fontdef1").shift.text if message.content.match(/^.capricorn/)
		 client.room.say "Aquarius: " + Nokogiri::HTML(open("http://my.horoscope.com/astrology/free-daily-horoscope-aquarius.html")).css("div.fontdef1").shift.text if message.content.match(/^.aquarius/)
		 client.room.say "Pisces: " + Nokogiri::HTML(open("http://my.horoscope.com/astrology/free-daily-horoscope-pisces.html")).css("div.fontdef1").shift.text if message.content.match(/^.pisces/)

	end

	if ( message.content.match(/^.bd_idle_lookup/))
	now = Time.new().to_i
		$antiIdle.each do |dj|
			user = client.user(dj['user'])
			client.room.say("#{dj['user']} = #{user.name} Idle: #{now - dj['timer'].to_i}")
		end
		client.room.say(client.user('4ea8d05fa3f751271d024366').name)
	end		
	# pp $botData['pkg_b_data']

end

def processAntiIdle(client, user, loc)
	#Validate list of dj's is current
	mydjs = []
	b_mydjs = []
	now = Time.new()
	pp "Anti-Idle Processing"
	#Add any new ones that did just join
	client.room.djs.each do |ndj|
		newdj = true
		$antiIdle.each do |odj|
			newdj = false if odj['user'] == ndj.id
			mydjs.push(odj) if odj['user'] == ndj.id
			end
		if newdj
			a_newdj = {}
			a_newdj['user'] = ndj.id
			a_newdj['warned'] = false
			a_newdj['booted'] = false
			a_newdj['timer'] = now.to_i
			mydjs.push(a_newdj)
			end
		end

	mydjs.each do |dj|
		dj['timer'] = now if user.id == dj['user']
		b_mydjs.push(dj) if client.room.djs.include?(client.user(dj['user']))
 		end
	mydjs = []
	#Ok validate they haven't hit one of the clips
	b_mydjs.each do |dj|
	
		if ( now.to_i - dj['timer'].to_i ) > $botData['pkg_b_data']['ai_msg_t'].to_i
			#boot
			client.room.say($botData['pkg_b_data']['ai_msg'])
			client.user(dj['user']).removedj
			#dj['booted'] = true
		elsif (( now.to_i - dj['timer'].to_i ) > $botData['pkg_b_data']['ai_w_msg_t'].to_i) and (!dj['warned'])
			#Warn
			#Flag
			client.room.say($botData['pkg_b_data']['ai_w_msg'])
			dj['warned'] = true
		end
		mydjs.push(dj) if !dj['booted']	
		end
	
	b_mydjs = Marshal.load(Marshal.dump(mydjs)) #overwrite the reference
	$antiIdle = Marshal.load(Marshal.dump(b_mydjs)) #overwrite the reference
end

#	Main block BEGIN
puts Process.pid
Turntabler.interactive

#	Start of EventMacine loop
Turntabler.run do

$jOutput = JSON.parse((URI.parse("http://www.neurobots.net/websockets/pull.php?bot_userid=#{$botData['userid']}&magic_key=#{$botData['magicKey']}")).read)
$botData['triggers'] = []
$botData['ads'] = []
$botData['events'] = []
$botData['acl'] = []

$botData['authid'] = $jOutput['bot_authid']
$botData['roomid'] = $jOutput['bot_roomid']
$botData['ownerid'] = $jOutput['owner_userid']
$botData['ads'] = $jOutput['adverts']
$botData['triggers'] = $jOutput['triggers']
$jOutput['blacklist'].pop
$botData['blacklist'] = $jOutput['blacklist'].map {|h| h['userid']}
$botData['command_trigger'] = $jOutput['command_trigger']
$botData['events'] = $jOutput['events']
$botData['events'].pop
$botData['triggers'].pop
$botData['ads'].pop
$botData['acl'] = $jOutput['acl']
$botData['acl'].pop
$botData['level1acl'] = []
$botData['level2acl'] = []
$botData['level3acl'] = []
$jOutput['acl'].each { |acl|
	$botData['level1acl'].push(acl['userid']) if acl['access_level'] == "1"
	$botData['level2acl'].push(acl['userid']) if acl['access_level'] == "2"
	$botData['level3acl'].push(acl['userid']) if acl['access_level'] == "3"
}

$botData['queue'] = false
$botData['slide'] = false

$botData['queue'] = true if $jOutput['start_queue'].to_i == 1
$botData['slide'] = true if $jOutput['start_slide'].to_i == 1

$sayings = []
$db.query("select * from bot_sayings_#{$botData['magicKey']}").each do |row|
	$sayings.push(row[0]);
	end

# Turntable socket
client = Turntabler::Client.new('', '', :room => $botData['roomid'], :user_id => $botData['userid'], :auth => $botData['authid'], :reconnect => true, :reconnect_wait => 15)
rehash(client, nil)

#Make sure everyone is in the db on entering the room

client.room.listeners.each do |user|
$db.query("insert into bot_ustats_#{$botData['magicKey']} set userid='#{user.id}', last_seen='#{`date`.chomp}', name='#{$db.escape_string(user.name)}' on duplicate key update last_seen='#{`date`.chomp}', name='#{$db.escape_string(user.name)}'")
end

#	Blacklist timer
	EventMachine::PeriodicTimer.new(10) do
		Turntabler.run {
		
		client.room.become_dj if (client.room.djs.count < 2) && (!client.user.dj?) && ($botData['autodj']) && ($botData['alonedj'])
		client.room.become_dj if (client.room.djs.count < 2) && (!client.user.dj?) && ($botData['autodj']) && (!$botData['alonedj']) && (client.room.djs.count > 0)
		
		client.user.remove_as_dj if (client.room.djs.count > 2 ) && (client.user.dj?) && (client.room.current_dj != client.user) && ($botData['autodj'])
		client.user.remove_as_dj if (client.user.dj?) && ( client.room.djs.count == 1 ) && (!$botData['alonedj'])
                client.room.listeners.each do |user|
			user.boot('Blacklisted') if $botData['blacklist'].include?(user.id) 
			end
		}
	end
#	Mod added
        client.on :moderator_added do |user|
		processEvent( client, user, "#moderator_added" )
                end
#	Fanned
#	client.on :fan_added do |user, fan_of| # User, User
#		processEvent( client, user, "#fan_added" )
#		end
#	someone booed off stage
#        client.on :dj_booed_off do |user|
#                processEvent( client, user, "#dj_booed_off" )
#		end
#	someone escorted off stage
#        client.on :dj_escorted_off do |user|
#                processEvent( client, user, "#dj_escorted_off" )
#		end
#	someone started dj'ing
	client.on :dj_added do |user|
		$call_user = 0 if $called_user = user
		processEvent( client, user, "#dj_added" )
		processAntiIdle(client, user,0) if (/B/ =~ $botData['flags']) and ($botData['pkg_b_data']['anti_idle'].to_i == 1)
		
		if ( $queue.count > 0 ) && ( !$tabledjs.include?(user) ) && $botData['queue']
			client.room.say("I'm sorry \@#{user.name}, but it isn't your turn yet.  People are waiting in the queue to play")
			user.remove_as_dj
			$dont_run_spooler = true
		elsif ( $queue.count == 0 ) && $botData['queue']
			$tabledjs.push(user)	
		end
		end
#	someone quit dj'ing
        client.on :dj_removed do |user|
                processEvent( client, user, "#dj_removed" )
		PorocessAntiIdle(client, user,0) if /B/ =~ $botData['flags'] and ($botData['pkg_b_data']['anti_idle'].to_i == 1)
		$tabledjs.delete(user) if $tabledjs.include?(user)
		if (!$running)&&(!$queue.empty?)
			$running = true
			$called_dj = $queue.shift
			$tabledjs.push($called_dj)
			client.room.say("Ok \@#{$called_dj.name}, you have 30 seconds to get to the stage")
			timer_handle = EventMachine.add_periodic_timer(30) do
				Turntabler.run {
					if client.room.djs.include?($called_dj)
						$running = false
						timer_handle.cancel
					else
						client.room.say("\@#{$called_dj.name} you took too long!")
						$tabledjs.delete($called_dj)
						if !$queue.empty?
							$called_dj = $queue.shift
							$tabledjs.push($called_dj)
							client.room.say("Ok \@#{$called_dj.name}, you have 30 seconds to get to the stage")
						else
							client.room.say("Nobody left in the queue!")
							$running = false
							timer_handle.cancel
						end
					end
						
				}
				end
			end





		end
#	someone updated their profile / name
#	client.on :user_updated do |user|
#                processEvent( client, user, "#dj_updated" )
#		end
#	client room info updated
	client.on :room_updated do |room| 
                $botData['events'].each { |event| client.room.say(event['pre_text'] + event['post_text']) if event['event'] == "#room_updated" }
                end

#	booted user
	client.on :user_booted do |boot|
		processEvent( client, boot.user, "#user_booted" )
		end 

#	song started
	client.on :song_started do |song|
		$db.query("insert into bot_sstats_#{$botData['magicKey']} set songid='#{digest(song.title, song.artist)}', title='#{$db.escape_string(song.title)}', artist='#{$db.escape_string(song.artist)}', first_user_played='#{song.played_by.id}' on duplicate key update times_played=times_played+1")
		$db.query("update bot_ustats_#{$botData['magicKey']} set songs_played=songs_played+1 where userid='#{song.played_by.id}'")
	
		EventMachine::Timer.new(song.length+5) do
                        song.skip if (client.room.current_song == song) && (client.room.current_dj == client.user)
			end
		$errorcounts = Hash.new
		end

#	song ended
	client. on :song_ended do |song|
		if song.played_by != client.user
		$db.query("update bot_sstats_#{$botData['magicKey']} set times_awesomed=times_awesomed+#{song.up_votes_count}, times_lamed=times_lamed+#{song.down_votes_count} where songid='#{digest(song.title, song.artist)}'")
		client.room.say("#{song.title}") if $botData['stats']
		client.room.say("Round:[ #{song.up_votes_count} :thumbsup:  ][ #{song.down_votes_count} :thumbsdown:  ][ #{$snagged} <3  ]") if $botData['stats']
		$snagged=0
		
		$db.query("select times_awesomed, times_lamed, times_snagged, times_played from bot_sstats_#{$botData['magicKey']} where songid='#{digest(song.title, song.artist)}' limit 1").each do |lsong|
			client.room.say("Life:[ #{lsong[0]} :thumbsup:  ][ #{lsong[1]} :thumbsdown:  ][ #{lsong[2]} <3  ][ #{lsong[3]} :dvd:  ]") if $botData['stats']
			end	
		song.votes.each do |vote|
			$db.query("update bot_ustats_#{$botData['magicKey']} set songs_awesomed=songs_awesomed+1 where userid='#{vote.user.id}'") if vote.direction == :up
			$db.query("update bot_ustats_#{$botData['magicKey']} set songs_lamed=songs_lamed+1 where userid='#{vote.user.id}'") if vote.direction == :down
			end
		end
		
		$queue.push(song.played_by) if ($queue.count > 0)&&($botData['autoReQueue'])
				

		if $botData['slide'] && client.room.djs.count > 3
			if client.room.djs.first == song.played_by
				client.room.say("Thank you \@#{song.played_by.name}, could you please slide for us? (Auto remove in 20 seconds)")
				dj_to_boot = song.played_by
				EventMachine::Timer.new(20) do
					Turntabler.run {
						if client.room.djs.first == dj_to_boot
							client.room.say("Removing #{dj_to_boot.name}")
							dj_to_boot.remove_as_dj
							end
					}
				end

			end
			end
		end

#	song snag
	client.on :song_snagged do |snag|
                $db.query("update bot_ustats_#{$botData['magicKey']} set songs_snagged=songs_snagged+1 where userid='#{snag.user.id}'")
		$db.query("update bot_ustats_#{$botData['magicKey']} set songs_shared=songs_shared+1 where userid='#{client.room.current_dj.id}'")
		$db.query("update bot_sstats_#{$botData['magicKey']} set times_snagged=times_snagged+1 where songid='#{digest(snag.song.title, snag.song.artist)}'")
		processEvent( client, snag.user, "#song_snagged" )
		$snagged+=1
		processAntiIdle(client, snag.user,0) if (/B/ =~ $botData['flags'])and($botData['pkg_b_data']['anti_idle'].to_i == 1)

		end
#	User Lamed
	client.on :song_voted do |song|
		person = song.votes.pop
		#client.room.say(":song_voted triggered vote counted #{person.user.name} #{person.direction}")
		processEvent( client, person.user, "#song_lamed" ) if person.direction == :down
		processAntiIdle(client, person.user,0) if (/B/ =~ $botData['flags'])and($botData['pkg_b_data']['anti_idle'].to_i == 1)
		end

#	Name change
	client.on :user_name_updated do |user|
		$db.query("update bot_ustats_#{$botData['magicKey']} set name='#{$db.escape_string(user.name)}' where userid='#{user.id}'")
		end
#	onjoin
	client.on :user_entered do |user| 
		if $botData['blacklist'].include?(user.id) 
			user.boot('Blacklisted') 	
		elsif user.id == client.user.id
			# No op
		else
		$db.query("insert into bot_ustats_#{$botData['magicKey']} set userid='#{user.id}', last_seen='#{`date`.chomp}', name='#{$db.escape_string(user.name)}' on duplicate key update last_seen='#{`date`.chomp}', name='#{$db.escape_string(user.name)}' ")
		
		EventMachine::Timer.new(5) { Turntabler.run { processEvent( client, user, '#user_entered') } }
		end
	end
#	on part
        client.on :user_left do |user|
		$db.query("update  bot_ustats_#{$botData['magicKey']} set last_seen='#{`date`.chomp}' where userid='#{user.id}'")
		processEvent( client, user, "#user_left" )
		if $queue.include?(user)
			EventMachine::Timer.new(20) do
				Turntabler.run { $queue.delete(user) if !client.room.listeners.include?(user) }
				end
			end
		end
#	User spoke in room
	client.on :user_spoke do |message|
		if message.sender.id != client.user.id
			processTriggers(client, message)
			processPkgB(client, message,0) if /B/ =~ $botData['flags']
			processAntiIdle(client, message.sender,0) if (/B/ =~ $botData['flags'])and($botData['pkg_b_data']['anti_idle'].to_i == 1)
		end
		end
	client.on :message_received do |message|
		processTriggers(client, message)
		processPkgB(client, message, 1) if /B/ =~ $botData['flags']
		end
end
 
