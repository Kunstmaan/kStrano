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
  
  def say(text)
    Capistrano::CLI.ui.say("  * #{text}")
  end

  def ask(question)
    agree = Capistrano::CLI.ui.agree("    #{question} ") do |q|
      q.default = 'n'
    end

    agree
  end

  module_function :poll, :say, :ask
  
end