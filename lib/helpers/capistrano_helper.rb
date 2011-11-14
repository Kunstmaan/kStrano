module Kumastrano
  class CapistranoHelper
    
    def say(text)
      Capistrano::CLI.ui.say("  * #{text}")
    end

    def ask(question)
      agree = Capistrano::CLI.ui.agree("    #{question} ") do |q|
        q.default = 'n'
      end

      agree
    end
    
  end
end