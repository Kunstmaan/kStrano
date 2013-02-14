module Kumastrano
    
  def poll(msg=nil, seconds=10.0, interval_seconds=1.0) 
    (seconds / interval_seconds).to_i.times do
      result = yield
      return if result
      sleep interval_seconds
    end
    msg ||= "polling failed after #{seconds} seconds" 
    raise msg
  end
  
  def say(text, prefix='--> ')
    Capistrano::CLI.ui.say("#{prefix}#{text}")
  end

  def ask(question, default='n')
    agree = Capistrano::CLI.ui.agree("--> #{question} ") do |q|
      q.default = default
    end

    agree
  end

  module_function :poll, :say, :ask
  
end