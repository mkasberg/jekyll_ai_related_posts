require 'active_record'
require 'sqlite3'
require 'sqlite_vss'
require 'jekyll'
require 'debug'

module JekyllAiRelatedPosts
  class Generator < Jekyll::Generator
    DIMENSIONS = 1536

    def generate(site)
      @site = site
      
      Jekyll.logger.info '[ai_related_posts] Generating related posts...'
      puts @site.config['ai_related_posts']['openai_api_key']
      #OpenAiEmbeddings.new(@site.config['ai_related_posts']['openai_api_key'])
      setup_database

      @site.posts.docs.each do |p|
        save_embeddings(p)
      end

      @site.posts.docs.each do |p|
        find_related(p)
      end
    end

    private

    def save_embeddings(post)
      existing = Models::Post.find_by(relative_path: post.relative_path)
      if existing.nil?
        Models::Post.create!(relative_path: post.relative_path, embedding: embedding_for(post))
      end
    end

    def find_related(post)
      post.data['ai_related_posts'] = @site.posts.docs.first(3)
    end

    def embedding_for(post)
      Jekyll.logger.debug "[ai_related_posts] Fetching embeddings for #{post.relative_path}"
      input = "Title: #{post.data['title']}"
      unless post.data['categories'].empty?
        input += "; Categories: #{post.data['categories'].join(', ')}"
      end
      unless post.data['tags'].empty?
        input += "; Tags: #{post.data['tags'].join(', ')}"
      end


      input
    end
    
    def setup_database
      ActiveRecord::Base.establish_connection(
        adapter: 'sqlite3',
        database: '.ai_related_posts_cache.sqlite3' # Path to your SQLite3 database file
      )
      # We don't need WAL mode for this.
      ActiveRecord::Base.connection.execute('PRAGMA journal_mode=DELETE;')

      # Enable sqlite-vss vector extension
      db = ActiveRecord::Base.connection.raw_connection
      db.enable_load_extension(true)
      SqliteVss.load(db)
      db.enable_load_extension(false)

      create_posts = <<-SQL
        CREATE TABLE IF NOT EXISTS posts(
          relative_path TEXT PRIMARY KEY,
          embedding TEXT
        );
      SQL
      ActiveRecord::Base.connection.execute(create_posts)

      create_vss_posts = <<-SQL
        CREATE VIRTUAL TABLE IF NOT EXISTS vss_posts using vss0(
          post_embedding(DIMENSIONS)
        );
      SQL
      ActiveRecord::Base.connection.execute(create_vss_posts)

      Jekyll.logger.debug("ai_related_posts db setup complete")
    end
  end
end
