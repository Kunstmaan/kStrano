Gem::Specification.new do |s|
  s.name        = 'kstrano'
  s.version     = '0.0.1'
  s.summary     = <<-DESC.strip.gsub(/\n\s+/, " ")
    Deploying Kunstmaan applications with Capistrano, Jenkins and GIT.
  DESC
  s.description = <<-DESC.strip.gsub(/\n\s+/, " ")
    Deploying Kunstmaan applications with Capistrano, Jenkins and GIT.
  DESC

  s.files       = Dir.glob("lib/**/*")
  s.require_path = 'lib'
  s.has_rdoc    = false
  
  s.author      = "Kunstmaan"
  s.email       = 'hello@kunstmaan.be'
  s.homepage    = 'http://www.kunstmaan.be'
  
  s.add_dependency(%q<capistrano>, [">= 2.9.0"])
  s.add_dependency(%q<json>, [">= 1.6.1"])
  s.add_dependency(%q<broach>, [">= 0.2.1"])
end