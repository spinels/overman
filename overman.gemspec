$:.unshift File.expand_path("../lib", __FILE__)
require "foreman/version"

Gem::Specification.new do |gem|
  gem.name     = "overman"
  gem.license  = "MIT"
  gem.version  = Foreman::VERSION

  gem.author   = "David Dollar"
  gem.email    = "ddollar@gmail.com"
  gem.homepage = "https://github.com/spinels/foreman"
  gem.summary  = "Process manager for applications with multiple components, " \
                 "fork of ddollar/foreman"

  gem.description = gem.summary

  gem.executables = "overman"
  gem.files = Dir["**/*"].select { |d| d =~ %r{^(README|bin/|data/|ext/|lib/|spec/|test/)} }
  gem.files << "man/overman.1"
end
