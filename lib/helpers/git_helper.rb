module Kumastrano
  class GitHelper
    
    require 'cgi'
    
    def self.fetch
      %x(git fetch)
    end
    
    def self.merge_base(commit1, commit2 = "HEAD")
      base = %x(git merge-base #{commit1} #{commit2})
      base.strip
    end
    
    def self.commit_hash(commit = "HEAD")
      hash = %x(git rev-parse #{commit})
      hash.strip
    end
    
    def self.branch_name(commit = "HEAD")
      name = %x(git name-rev --name-only #{commit})
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