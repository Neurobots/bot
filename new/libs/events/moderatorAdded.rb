module Moderatoradded

	  def moderatorAddedInit

    self.client.on :moderator_added do |user|
      processEvent( client, user, "#moderator_added" )
    end

  end


end
