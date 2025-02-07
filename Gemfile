source "http://rubygems.org"

gemspec

gem 'thor', '0.19.4', :require => false

group :test do
  gem 'irb' # for fakefs (https://github.com/fakefs/fakefs/pull/494)
            # "irb was loaded from the standard library, but is not part of the default gems starting from Ruby 3.5.0"
  gem 'rake'
  gem 'fakefs'
  gem 'rspec',  '~> 3.5'
  gem "simplecov", :require => false
  gem 'timecop'
end

group :development do
  gem 'aws-s3'
  gem 'ronn-ng'
  gem 'yard', '~> 0.9.11'
end
