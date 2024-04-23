# frozen_string_literal: true

require_relative "lib/jekyll_ai_related_posts/version"

Gem::Specification.new do |spec|
  spec.name = "jekyll_ai_related_posts"
  spec.version = JekyllAiRelatedPosts::VERSION
  spec.authors = [ "Mike Kasberg" ]
  spec.email = [ "kasberg.mike@gmail.com" ]

  spec.summary = "Populate ai_related_posts using Open AI embeddings"
  spec.description = "Populate ai_related_posts using Open AI embeddings"
  spec.homepage = "https://github.com/mkasberg/jekyll_ai_related_posts"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mkasberg/jekyll_ai_related_posts"
  spec.metadata["changelog_uri"] = "https://github.com/mkasberg/jekyll_ai_related_posts"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "activerecord", "~> 7.1"
  spec.add_dependency "faraday", "~> 2.9"
  spec.add_dependency "jekyll", ">= 3.0"
  spec.add_dependency "sqlite3", "~> 1.4"
  spec.add_dependency "sqlite-vss", "~> 0.1.2"
  spec.add_dependency "zeitwerk", "~> 2.6"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
