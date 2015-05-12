source 'https://rubygems.org'

group :test, :development do
  gem 'pg'
  gem 'sequel'
  gem 'que', git: 'git@github.com:gocardless/que.git'
end

group :test do
  gem 'rspec', '~> 2.14.1'
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'json', '~> 1.8'
end

gemspec
