# frozen_string_literal: true

require "json"

RSpec.describe JekyllAiRelatedPosts::ApiEmbeddings do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:conn) do
    Faraday.new do |builder|
      builder.adapter :test, stubs
      builder.request :authorization, "Bearer", "my_key"
      builder.request :json
      builder.response :json
      builder.response :raise_error
    end
  end
  subject do
    JekyllAiRelatedPosts::ApiEmbeddings.new("my_key", connection: conn)
  end

  it "makes a request to the embeddings API" do
    stubs.post("/v1/embeddings") do |_env|
      [
        200,
        { "Content-Type" => "application/json" },
        { data: [ { embedding: [ 0.01, 0.02 ] } ] }.to_json
      ]
    end

    expect(subject.embedding_for("My test")).to eq([ 0.01, 0.02 ])
  end

  it "handles an unexpected response structure" do
    stubs.post("/v1/embeddings") do |_env|
      [
        200,
        { "Content-Type" => "application/json" },
        { data: [ { object: "embedding", index: 0 } ] }.to_json
      ]
    end

    expect { capture_output { subject.embedding_for("My test") } }.to raise_error(JekyllAiRelatedPosts::Error, /Unexpected API response/)
  end

  it "handles an error response" do
    stubs.post("/v1/embeddings") do |_env|
      [
        429,
        { "Content-Type" => "application/json" },
        {
          error: {
            message: "You exceeded your current quota, please check your plan and billing details.",
            type: "insufficient_quota",
            param: nil,
            code: "insufficient_quota"
          }
        }.to_json
      ]
    end

    expect { capture_output { subject.embedding_for("My test") } }.to raise_error Faraday::Error
  end

  it "has default dimensions" do
    stubs.post("/v1/embeddings") do
      [
        200,
        { "Content-Type" => "application/json" },
        { data: [ { embedding: [ 0.01 ] * 1536 } ] }.to_json
      ]
    end

    expect(subject.dimensions).to eq(1536)
  end

  context "with custom url and model" do
    subject do
      JekyllAiRelatedPosts::ApiEmbeddings.new(
        "my_key",
        api_url: "https://openrouter.ai/api",
        model: "openai/text-embedding-3-small",
        connection: conn
      )
    end

    it "discovers dimensions from the API response" do
      stubs.post("/v1/embeddings") do
        [
          200,
          { "Content-Type" => "application/json" },
          { data: [ { embedding: [ 0.01 ] * 768 } ] }.to_json
        ]
      end

      expect(subject.dimensions).to eq(768)
    end

    it "sends the custom model in the request body" do
      stubs.post("/v1/embeddings") do |env|
        body = JSON.parse(env.body)
        expect(body["model"]).to eq("openai/text-embedding-3-small")
        [
          200,
          { "Content-Type" => "application/json" },
          { data: [ { embedding: [ 0.01, 0.02 ] } ] }.to_json
        ]
      end

      subject.embedding_for("My test")
    end
  end
end
