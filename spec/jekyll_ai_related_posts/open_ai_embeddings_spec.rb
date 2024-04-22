# frozen_string_literal: true
require 'json'

RSpec.describe JekyllAiRelatedPosts::OpenAiEmbeddings do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:conn) do
    Faraday.new do |builder|
      builder.adapter :test, stubs
      builder.request :authorization, 'Bearer', 'my_key'
      builder.request :json
      builder.response :json
      builder.response :raise_error
    end
  end
  subject do
    JekyllAiRelatedPosts::OpenAiEmbeddings.new('my_key', connection: conn)
  end

  it 'makes a request to OpenAI API' do
    stubs.post('/v1/embeddings') do |env|
      [
        200,
        { 'Content-Type' => 'application/json' },
        { data: [ { embedding: [ 0.01, 0.02] } ] }.to_json
      ]
    end

    expect(subject.embedding_for('My test')).to eq([0.01, 0.02])
  end

  it 'handles an error response' do
    stubs.post('/v1/embeddings') do |env|
      [
        429,
        { 'Content-Type' => 'application/json' },
        {
          error: {
            message: "You exceeded your current quota, please check your plan and billing details. For more information on this error, read the docs: https://platform.openai.com/docs/guides/error-codes/api-errors.",
            type: "insufficient_quota",
            param: nil,
            code: "insufficient_quota"
          }
        }.to_json
      ]
    end

    expect { capture_output { subject.embedding_for('My test') } }.to raise_error Faraday::Error
  end
end
