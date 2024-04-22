# frozen_string_literal: true
require 'debug'
require 'ostruct'

RSpec.describe JekyllAiRelatedPosts::Generator do
  let(:config_overrides) do
    {
      'ai_related_posts' => {
        'openai_api_key' => 'my_key',
        'embeddings_source' => 'mock'
      },
    }
  end
  let(:site) do
    fixture_site(config_overrides)
  end

  before(:each) do
    File.delete(site.in_source_dir('.ai_related_posts_cache.sqlite3'))
  rescue Errno::ENOENT
  end

  it 'generates related posts' do
    site.process

    wifi_upgrades = File.read(dest_dir("2023", "12", "22", "home-wifi-upgrades-adding-an-access-point-with-wired-backhaul.html"))
    expect(wifi_upgrades).to include('1:::Analyzing Static Website Logs with AWStats')
    expect(wifi_upgrades).to include('2:::Catching Mew: A Playable Game Boy Quote')
  end

  it 'regenerates when posts are edited' do
    # Create the cache
    site.process

    contents = File.read('spec/source/_posts/2023-12-22-home-wifi-upgrades-adding-an-access-point-with-wired-backhaul.md')
    contents.gsub!(/title:.+/, 'title: How to Catch Pokemon')
    File.open('spec/source/_posts/2023-12-22-home-wifi-upgrades-adding-an-access-point-with-wired-backhaul.md', 'w') do |file|
      file.write(contents)
    end

    expect_any_instance_of(MockEmbeddings)
      .to receive(:embedding_for)
      .with('Title: How to Catch Pokemon; Tags: Technology')
      .and_call_original
    site.process
  ensure
    contents.gsub!(/title:.+/, 'title: "Home WiFi Upgrades: Adding an Access Point with Wired Backhaul"')
    File.open('spec/source/_posts/2023-12-22-home-wifi-upgrades-adding-an-access-point-with-wired-backhaul.md', 'w') do |file|
      file.write(contents)
    end
  end
end
