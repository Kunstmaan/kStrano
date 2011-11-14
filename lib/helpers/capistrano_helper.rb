module Kumastrano
  class CapistranoHelper
    
    def self.say(text)
      Capistrano::CLI.ui.say("  * #{text}")
    end

    def self.ask(question)
      agree = Capistrano::CLI.ui.agree("    #{question} ") do |q|
        q.default = 'n'
      end

      agree
    end
    
  end
end