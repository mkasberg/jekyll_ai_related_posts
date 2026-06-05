# frozen_string_literal: true

require "faraday"

module JekyllAiRelatedPosts
  class ApiEmbeddings
    DEFAULT_API_URL = "https://api.openai.com"
    DEFAULT_MODEL = "text-embedding-3-small"
    DEFAULT_DIMENSIONS = 1536

    def initialize(api_key, api_url: nil, model: nil, connection: nil)
      @api_url = api_url || DEFAULT_API_URL
      @model = model || DEFAULT_MODEL
      @dimensions = nil

      @connection = if connection.nil?
        Faraday.new(url: @api_url) do |builder|
          builder.request :authorization, "Bearer", api_key
          builder.request :json
          builder.response :json
          builder.response :raise_error
        end
      else
        connection
      end
    end

    def dimensions
      @dimensions ||= discover_dimensions
    end

    def embedding_for(text)
      res = @connection.post("/v1/embeddings") do |req|
        req.body = {
          input: text,
          model: @model
        }
      end

      embedding = res.body["data"].first["embedding"]
      @dimensions ||= embedding.length
      embedding
    rescue Faraday::Error => e
      Jekyll.logger.error "AI Related Posts:", "Error response from embeddings API!"
      Jekyll.logger.error "AI Related Posts:", e.inspect

      raise
    end

    private

    def discover_dimensions
      embedding_for("test").length
    end
  end
end
