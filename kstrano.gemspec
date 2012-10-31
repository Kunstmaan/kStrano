Gem::Specification.new do |s|
  s.name        = 'kstrano'
  s.version     = '0.0.27'
  s.summary     = <<-DESC.strip.gsub(/\n\s+/, " ")
    Deploying applications with Capistrano, Jenkins and GIT.
  DESC
  s.description = <<-DESC.strip.gsub(/\n\s+/, " ")
    Deploying applications with Capistrano, Jenkins and GIT.
  DESC

  s.files       = Dir.glob("lib/**/*")
  s.require_path = 'lib'
  s.has_rdoc    = false

  s.bindir = "bin"
  s.executables << "kumafy"

  s.author      = "Kunstmaan"
  s.email       = 'support@kunstmaan.be'
  s.homepage    = 'https://github.com/Kunstmaan/kStrano'

  s.add_dependency(%q<capistrano>, [">= 2.12.0"])
  s.add_dependency(%q<capistrano-ext>, [">=1.2.1"])
  s.add_dependency(%q<capistrano_colors>, [">=0.5.5"])
  s.add_dependency(%q<capifony>, ["=2.1.15"])
  s.add_dependency(%q<json>, [">= 1.6.6"])
  s.add_dependency(%q<broach>, [">= 0.2.1"])
  s.add_dependency(%q<highline>, [">= 1.6.11"])
end