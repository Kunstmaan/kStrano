module Kumastrano
  
  def poll(msg=nil, seconds=5.0) 
    (seconds / 5).to_i.times do
      result = yield
      puts result
      return if result
      sleep 5.0
    end
    msg ||= "polling failed after #{seconds} seconds" 
    raise msg
  end

  module_function :poll
  
end