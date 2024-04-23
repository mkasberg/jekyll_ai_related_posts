# frozen_string_literal: true

require "faraday"

module JekyllAiRelatedPosts
  class OpenAiEmbeddings
    DIMENSIONS = 1536

    def initialize(api_key, connection: nil)
      @connection = if connection.nil?
                      Faraday.new(url: "https://api.openai.com") do |builder|
                        builder.request :authorization, "Bearer", api_key
                        builder.request :json
                        builder.response :json
                        builder.response :raise_error
                      end
                    else
                      connection
                    end
    end

    def embedding_for(text)
      res = @connection.post("/v1/embeddings") do |req|
        req.body = {
          input: text,
          model: "text-embedding-3-small"
        }
      end

      res.body["data"].first["embedding"]
    rescue Faraday::Error => e
      Jekyll.logger.error "Error response from OpanAI API!"
      Jekyll.logger.error e.inspect

      raise
    end
  end
end
