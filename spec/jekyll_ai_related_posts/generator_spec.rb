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
    File.delete('.ai_related_posts_cache.sqlite3')
  end

  it 'generates related posts' do
    site.process

    wifi_upgrades = File.read(dest_dir("2023", "12", "22", "home-wifi-upgrades-adding-an-access-point-with-wired-backhaul.html"))
    expect(wifi_upgrades).to include('1:::Analyzing Static Website Logs with AWStats')
    expect(wifi_upgrades).to include('2:::Catching Mew: A Playable Game Boy Quote')
  end
end
