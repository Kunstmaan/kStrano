module Kumastrano
  class GitHelper
    
    require 'cgi'
    
    def self.git_hash
      hash = %x(git rev-parse HEAD)
      hash.strip
    end
    
    def self.branch_name
      name = %x(git name-rev --name-only HEAD)
      name.strip
    end
    
    def self.origin_refspec
      refspec = %x(git config remote.origin.fetch)
      refspec.strip
    end
    
    def self.origin_url
      url = %x(git config remote.origin.url)
      url.strip
    end
    
  end
end