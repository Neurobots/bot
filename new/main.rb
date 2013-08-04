#!/usr/bin/env ruby

# Basic requires needed to make this possible

require 'rubygems'
require 'turntabler'
require 'monitor'
require 'eventmachine'
require 'json'
require 'open-uri'
require 'pp'
require 'mysql'
require 'digest/md5'
require 'nokogiri'

CODENAME = "neuroBot"
VERSION = "1.0 Alpha"

# Sanitize the envrioment first, the enviroment should have the magic key and the command line the bot_userid.  
# The bot userid is consider public knowledge so there is no desire to protect that.  
# However the magic_key is how we two factor everything, so we want to protect that.

# Check for magic key first

abort "No magic key in envrioment variable" if !ENV.include? 'MAGICKEY' 

# Set constatnt for magic key

MAGICKEY = ENV['MAGICKEY'] if ENV.include? 'MAGICKEY'

# Check for bot userid

abort "No Bot Userid found.  Usage: ./main <bot userid>" if !(ARGV.count > 0)

# Set constant for bot userid

USERID = ARGV.shift if ARGV.count > 0 

puts "#{USERID} #{MAGICKEY} #{Process.pid}"
puts "#{CODENAME} #{VERSION}"

class Neurobot
	
	def initalize
	
		# Create db handle
		
		@db = Mysql::new("hal", "nirvana_neurobot", "571b7c5a6fe4", "neurobots")
		
		# Create our instance variables

		@botData = Hash.new
		
		# Load the first pass of bot variables		

		jOutput = JSON.parse((URI.parse("http://www.neurobots.net/websockets/pull.php?bot_userid=#{USERID}&magic_key=#{MAGICKEY}")).read)
		
		@botData['authid'] = jOutput['bot_authid']
		@botData['roomid'] = jOutput['bot_roomid']
		@botData['ownerid'] = jOutput['owner_userid']

		# Start Eventmachine main loop
		
		Turntabler.interactive
		Turntabler.run do

		# Start the client handle
		
		@client = Turntabler::Client.new('', '', :room => @botData['roomid'], :user_id => @botData['userid'], :auth => @botData['authid'], :reconnect => true, :reconnect_wait => 15)

		# Pull in all the information and spit out the startup
		
		rehash(@client, nil)


		end # End Turntabler.run do

	end
	
	def rehash(client, user)
		
		jOutput = JSON.parse((URI.parse("http://www.neurobots.net/websockets/pull.php?bot_userid=#{USERID}&magic_key=#{MAGICKEY}")).read)
		
		@errorcounts = {}
		@antiIdle = []
		@sayings = []

		@botData['authid'] = jOutput['bot_authid']
		@botData['roomid'] = jOutput['bot_roomid']
		@botData['ownerid'] = jOutput['owner_userid']
		@botData['ads'] = jOutput['adverts']
		@botData['triggers'] = jOutput['triggers']
		@botData['command_trigger'] = jOutput['command_trigger']
		@botData['events'] = jOutput['events']
		@botData['events'].pop
		@botData['triggers'].pop
		@botData['ads'].pop
		@botData['level1acl'] = []
		@botData['level2acl'] = []
		@botData['level3acl'] = []
		@botData['queue'] = false
		@botData['slide'] = false
		@botData['autodj'] = false
		@botData['stats'] = false
		@botData['autoReQueue'] = false
		@botData['alonedj'] = false
		@botData['flags'] = jOutput['flags']
		@botData['queue'] = true if jOutput['start_queue'].to_i == 1
		@botData['slide'] = true if jOutput['start_slide'].to_i == 1
		@botData['autodj'] = true if jOutput['start_autodj'].to_i == 1
		@botData['stats'] = true if jOutput['start_stats'] .to_i == 1
		@botData['autoReQueue'] = true if jOutput['switch_autorequeue'] .to_i == 1
		@botData['alonedj'] = true if jOutput['switch_alonedj'] .to_i == 1

		
		jOutput['blacklist'].pop
		@botData['blacklist'] = jOutput['blacklist'].map {|h| h['userid']}
		
		jOutput['acl'].pop
		jOutput['acl'].each { |acl|
        @botData['level1acl'].push(acl['userid']) if acl['access_level'] == "1"
        @botData['level2acl'].push(acl['userid']) if acl['access_level'] == "2"
        @botData['level3acl'].push(acl['userid']) if acl['access_level'] == "3"
		}
		
		('B'..'B').each do |pkg|
        @botData['pkg_'+pkg.downcase+'_data'] = jOutput['pkg_'+pkg.downcase+'_data'][0] if /#{pkg}/ =~ @botData['flags']
		end

		@tabledjs = client.room.djs.to_a if @botData['queue']


		if jOutput['mods_to_lvl1'].to_i == 1
    	client.room.moderators.each do |mod|
      	@botData['level1acl'].push(mod.id)
      end
		end

		@db.query("select * from bot_sayings_#{$botData['magicKey']}").each do |row|
    	@sayings.push(row[0]);
    end

		if user == nil
			client.room.say("#{CODENAME} #{VERSION}")
			client.room.say("triggers: #{@botData['triggers'].count} ads: #{@botData['ads'].count} events: #{@botData['events'].count} acls: #{jOutput['acl'].count} sayings: #{@sayings.count} ") 
      client.room.say("Package B Activated") if /B/ =~ @botData['flags']
		else
			user.say("#{CODENAME} #{VERSION}")
			user.say("triggers: #{@botData['triggers'].count} ads: #{@botData['ads'].count} events: #{@botData['events'].count} acls: #{jOutput['acl'].count} sayings: #{@sayings.count} ")
			user.say("Package B Activated") if /B/ =~ @botData['flags']
		end

		# Ad Spooler
    
		@botData['running_timers'].each { |timer| timer.cancel }
    @botData['running_timers'] =  []
    @botData['ads'].each do |ad|
    	timer = EventMachine::PeriodicTimer.new(ad['delay']) do
      	Turntabler.run { client.room.say ad['message'] }
      end
      @botData['running_timers'].push(timer)
    end
    rescue JSON::ParserError, SocketError
	end
	
	def db
		@db
	end

end
