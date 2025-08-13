# frozen_string_literal: true

require_relative "lib/schwab/version"

Gem::Specification.new do |spec|
  spec.name = "schwab"
  spec.version = Schwab::VERSION
  spec.authors = ["Ryan Hamamura"]
  spec.email = ["58859899+ryanhamamura@users.noreply.github.com"]

  spec.summary = "Ruby SDK for Charles Schwab API"
  spec.description = "A Ruby client library for the Charles Schwab API, providing easy access to trading, market data, and portfolio management endpoints."
  spec.homepage = "https://github.com/ryanhamamura/schwab"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ryanhamamura/schwab"
  spec.metadata["changelog_uri"] = "https://github.com/ryanhamamura/schwab/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(["git", "ls-files", "-z"], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?("bin/", "test/", "spec/", "features/", ".git", ".github", "appveyor", "Gemfile")
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency("faraday", "~> 2.0")
  spec.add_dependency("multi_json", "~> 1.15")
  spec.add_dependency("oauth2", "~> 2.0")
  spec.add_dependency("sawyer", "~> 0.9")

  # Development dependencies for security analysis
  spec.add_development_dependency("brakeman", "~> 6.0")

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
