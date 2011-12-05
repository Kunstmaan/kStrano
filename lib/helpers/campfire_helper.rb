module Kumastrano
  class CampfireHelper
    
    require 'broach'
    
    def self.speak(campfire_account, campfire_token, campfire_room, message="")
      ## extracted this to here, because i don't know how to call capistrano tasks with arguments
      ## else i just had to make one capistrano task which i could call
      if !campfire_account.nil? && !campfire_token.nil? && !campfire_room.nil?
        
        Broach.settings = {
          'account' => campfire_account,
          'token' => campfire_token,
          'use_ssl' => true
        }
      
        room = Broach::Room.find_by_name campfire_room
      
        if !room.nil?
          room.speak message
        end
      end
    end
  end
end