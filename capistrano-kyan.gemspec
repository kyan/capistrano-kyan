# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'capistrano-kyan/version'

Gem::Specification.new do |gem|
  gem.name          = "capistrano-kyan"
  gem.version       = CapistranoKyan::VERSION
  gem.authors       = ["Duncan Robertson"]
  gem.email         = ["duncan@kyan.com"]
  gem.description   = %q{Capistrano tasks for database.yml and vhost creation}
  gem.summary       = %q{A bunch of useful Capistrano tasks}
  gem.homepage      = "http://github.com/kyan/capistrano-kyan"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]


  gem.add_development_dependency 'rake'

  gem.add_runtime_dependency 'capistrano', '~> 2.14.1'
end
