# frozen_string_literal: true

require_relative "jekyll_ai_related_posts/generator"

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.setup

module JekyllAiRelatedPosts
  GEM_ROOT = File.expand_path("..", __dir__)

  class Error < StandardError; end
end
