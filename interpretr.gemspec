require_relative 'lib/interpretr/version'

Gem::Specification.new do |spec|
  spec.name          = "interpretr"
  spec.version       = Interpretr::VERSION
  spec.authors       = ["Josh Bielick"]
  spec.email         = ["jbielick@gmail.com"]

  spec.summary       = %q{A framework for safely interpreting ruby code}
  spec.description   = %q{Interpetr is a configurable, pared-down ruby interpreter with access control features to allow or disallow the usage of ruby VM components or memory.}
  spec.homepage      = "https://github.com/jbielick/interpretr"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage + "/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "parser", "~> 2.7"
end
