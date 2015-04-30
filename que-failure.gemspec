# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'que/failure/version'

Gem::Specification.new do |spec|
  spec.name          = "que-failure"
  spec.version       = Que::Failure::VERSION
  spec.authors       = ["Baris Balic", "Chris Sinjakli"]
  spec.email         = ["baris@gocardless.com"]
  spec.summary       = %q{Alternative failure strategies for Que.}
  spec.description   = <<-EOL
    que-failure provides alternative failure strategies for failed Que jobs,
    including no retry and limited retries.
  EOL
  spec.homepage      = "https://github.com/gocardless/que-failure"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency('que', '>= 0.0')

  spec.add_development_dependency("rake", ">= 10.3")
  spec.add_development_dependency("rspec")
  spec.add_development_dependency("rubocop")
end
