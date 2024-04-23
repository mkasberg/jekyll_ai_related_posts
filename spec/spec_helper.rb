# frozen_string_literal: true

require "jekyll_ai_related_posts"

class MockEmbeddings
  def embedding_for(text)
    file =
      if text.include?("Mew")
        "catching_mew_embedding.json"
      elsif text.include?("AWStats")
        "awstats_embedding.json"
      else
        "home_wifi_embedding.json"
      end

    JSON.parse(File.read("spec/fixtures/#{file}"))
  end
end

# See https://github.com/jekyll/jekyll/blob/dbbfc5d48c81cf424f29c7b0eebf10886bc99904/test/helper.rb
module DirectoryHelpers
  def root_dir(*subdirs)
    File.expand_path(File.join("..", *subdirs), __dir__)
  end

  def dest_dir(*subdirs)
    test_dir("dest", *subdirs)
  end

  def source_dir(*subdirs)
    test_dir("source", *subdirs)
  end

  def theme_dir(*subdirs)
    test_dir("fixtures", "test-theme", *subdirs)
  end

  def test_dir(*subdirs)
    root_dir("spec", *subdirs)
  end

  def temp_dir(*subdirs)
    if Jekyll::Utils::Platforms.vanilla_windows?
      drive = Dir.pwd.sub(%r{^([^/]+).*}, '\1')
      temp_root = File.join(drive, "tmp")
    else
      temp_root = "/tmp"
    end

    File.join(temp_root, *subdirs)
  end
end

# See https://github.com/jekyll/jekyll/blob/dbbfc5d48c81cf424f29c7b0eebf10886bc99904/test/helper.rb
module JekyllHelpers
  include DirectoryHelpers
  extend DirectoryHelpers

  def fixture_document(relative_path)
    site = fixture_site(
      "collections" => {
        "methods" => {
          "output" => true
        }
      }
    )
    site.read
    matching_doc = site.collections["methods"].docs.find do |doc|
      doc.relative_path == relative_path
    end
    [site, matching_doc]
  end

  def fixture_site(overrides = {})
    Jekyll::Site.new(site_configuration(overrides))
  end

  def default_configuration
    Marshal.load(Marshal.dump(Jekyll::Configuration::DEFAULTS))
  end

  def build_configs(overrides, base_hash = default_configuration)
    Jekyll::Utils.deep_merge_hashes(base_hash, overrides)
  end

  def site_configuration(overrides = {})
    full_overrides = build_configs(
      overrides,
      build_configs(
        "destination" => dest_dir,
        "incremental" => false
      )
    )

    Jekyll::Configuration.from(full_overrides.merge("source" => source_dir))
  end

  def capture_output(level = :debug)
    buffer = StringIO.new
    Jekyll.logger = Logger.new(buffer)
    Jekyll.logger.log_level = level
    yield
    buffer.rewind
    buffer.string.to_s
  ensure
    Jekyll.logger = Logger.new(StringIO.new, :error)
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include(JekyllHelpers)
end
