module Processantiidle

def processAntiIdle(user, loc)
  #Validate list of dj's is current
  mydjs = []
  b_mydjs = []
  now = Time.new()
  pp "Anti-Idle Processing"
  #Add any new ones that did just join
  self.client.room.djs.each do |ndj|
    newdj = true
    @antiIdle.each do |odj|
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
    b_mydjs.push(dj) if self.client.room.djs.include?(self.client.user(dj['user']))
    end
  mydjs = []
  #Ok validate they haven't hit one of the clips
  b_mydjs.each do |dj|

    if ( now.to_i - dj['timer'].to_i ) > @botData['pkg_b_data']['ai_msg_t'].to_i
      #boot
      self.client.room.say(@botData['pkg_b_data']['ai_msg'])
      self.client.user(dj['user']).removedj
      #dj['booted'] = true
    elsif (( now.to_i - dj['timer'].to_i ) > @botData['pkg_b_data']['ai_w_msg_t'].to_i) and (!dj['warned'])
      #Warn
      #Flag
      self.client.room.say(@botData['pkg_b_data']['ai_w_msg'])
      dj['warned'] = true
    end
    mydjs.push(dj) if !dj['booted']
    end

  b_mydjs = Marshal.load(Marshal.dump(mydjs)) #overwrite the reference
  @antiIdle = Marshal.load(Marshal.dump(b_mydjs)) #overwrite the reference
end

end
