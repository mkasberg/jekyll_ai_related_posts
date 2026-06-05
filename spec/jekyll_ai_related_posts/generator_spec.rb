# frozen_string_literal: true

require "debug"
require "ostruct"

RSpec.describe JekyllAiRelatedPosts::Generator do
  let(:config_overrides) do
    {
      "ai_related_posts" => {
        "api_key" => "my_key",
        "embeddings_source" => "mock"
      }
    }
  end
  let(:site) do
    fixture_site(config_overrides)
  end

  before(:each) do
    File.delete(site.in_source_dir(".ai_related_posts_cache.sqlite3"))
  rescue Errno::ENOENT
  end

  it "generates related posts" do
    site.process

    wifi_upgrades = File.read(
      dest_dir("2023", "12", "22", "home-wifi-upgrades-adding-an-access-point-with-wired-backhaul.html")
    )
    expect(wifi_upgrades).to include("1:::Analyzing Static Website Logs with AWStats")
    expect(wifi_upgrades).to include("2:::Catching Mew: A Playable Game Boy Quote")
  end

  it "regenerates when posts are edited" do
    # Create the cache
    site.process

    contents = File.read("spec/source/_posts/2023-12-22-home-wifi-upgrades-adding-an-access-point-with-wired-backhaul.md")
    contents.gsub!(/title:.+/, "title: How to Catch Pokemon")
    File.open("spec/source/_posts/2023-12-22-home-wifi-upgrades-adding-an-access-point-with-wired-backhaul.md",
              "w") do |file|
      file.write(contents)
    end

    expect_any_instance_of(MockEmbeddings)
      .to receive(:embedding_for)
      .with("Title: How to Catch Pokemon; Tags: Technology")
      .and_call_original
    site.process
  ensure
    contents.gsub!(/title:.+/, 'title: "Home WiFi Upgrades: Adding an Access Point with Wired Backhaul"')
    File.open("spec/source/_posts/2023-12-22-home-wifi-upgrades-adding-an-access-point-with-wired-backhaul.md",
              "w") do |file|
      file.write(contents)
    end
  end

  context "fetch disabled" do
    let(:config_overrides) do
      {
        "ai_related_posts" => {
          "api_key" => "my_key",
          "embeddings_source" => "mock",
          "fetch_enabled" => false
        }
      }
    end

    it "does not fetch embeddings from the API" do
      expect_any_instance_of(MockEmbeddings).not_to receive(:embedding_for)

      site.process
    end
  end

  context "backward compatibility with openai_api_key" do
    let(:config_overrides) do
      {
        "ai_related_posts" => {
          "openai_api_key" => "my_key",
          "embeddings_source" => "mock"
        }
      }
    end

    it "still generates related posts" do
      site.process

      wifi_upgrades = File.read(dest_dir("2023", "12", "22",
                                         "home-wifi-upgrades-adding-an-access-point-with-wired-backhaul.html"))
      expect(wifi_upgrades).to include("1:::Analyzing Static Website Logs with AWStats")
      expect(wifi_upgrades).to include("2:::Catching Mew: A Playable Game Boy Quote")
    end
  end

  context "cache metadata mismatch" do
    it "raises an error when the cached model differs from config" do
      # First, create a cache with the default model
      default_config = {
        "ai_related_posts" => {
          "api_key" => "my_key",
          "embeddings_source" => "mock"
        }
      }
      default_site = fixture_site(default_config)
      default_site.process

      # Now change the config model and try again
      new_config = {
        "ai_related_posts" => {
          "api_key" => "my_key",
          "embeddings_source" => "mock",
          "model" => "different-model"
        }
      }
      new_site = fixture_site(new_config)

      expect { new_site.process }.to raise_error(JekyllAiRelatedPosts::Error, /Cache model mismatch/)
    end
  end
end
