require 'faraday'

module JekyllAiRelatedPosts
  class OpenAiEmbeddings
    def initialize(api_key, connection: nil)
      if connection.nil?
        @connection = Faraday.new(url: 'https://api.openai.com') do |builder|
          builder.request :authorization, 'Bearer', api_key
          builder.request :json
          builder.response :json
          builder.response :raise_error
        end
      else
        @connection = connection
      end
    end

    def embedding_for(text)
      res = @connection.post('/v1/embeddings') do |req|
        req.body = {
          input: text,
          model: 'text-embedding-3-small'
        }
      end

      res.body['data'].first['embedding']
    end
  end
end
