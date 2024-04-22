require 'active_record'
require 'sqlite3'
require 'sqlite_vss'
require 'jekyll'
require 'json'

module JekyllAiRelatedPosts
  class Generator < Jekyll::Generator

    def generate(site)
      @site = site

      Jekyll.logger.info '[ai_related_posts] Generating related posts...'
      setup_database

      @embeddings_fetcher = new_fetcher

      @site.posts.docs.each do |p|
        save_embeddings(p)
      end

      #insert_vss_rows

      @indexed_posts = {}
      site.posts.docs.each do |p|
        @indexed_posts[p.relative_path] = p
      end

      @site.posts.docs.each do |p|
        find_related(p)
      end
    end

    private

    def new_fetcher
      case @site.config['ai_related_posts']['embeddings_source']
      when 'mock'
        MockEmbeddings.new
      else
        OpenAiEmbeddings.new(@site.config['ai_related_posts']['openai_api_key'])
      end
    end

    def save_embeddings(post)
      existing = Models::Post.find_by(relative_path: post.relative_path)
      if existing.nil?
        Models::Post.create!(relative_path: post.relative_path, embedding: embedding_for(post).to_json)

        sql = <<-SQL
          INSERT INTO vss_posts (rowid, post_embedding)
            SELECT rowid, embedding FROM posts WHERE relative_path = :relative_path;
        SQL
        ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql([sql, relative_path: post.relative_path]))
      end
    end

    # def insert_vss_rows
    #   ActiveRecord::Base.connection.execute <<-SQL
    #     INSERT INTO vss_posts (rowid, post_embedding)
    #       select rowid, embedding from posts;
    #   SQL
    # end

    def find_related(post)
      sql = <<-SQL
        SELECT rowid, distance
        FROM vss_posts
        WHERE vss_search(
          post_embedding,
          (select embedding from posts where relative_path = :relative_path)
        )
        LIMIT 10000;
      SQL

      results = ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql([sql, relative_path: post.relative_path]))
      # The first result is the post itself, with a distance of 0.
      rowids = results.sort_by { |r| r['distance'] }.drop(1).first(3).map { |r| r['rowid'] }

      posts_by_rowid = {}
      rowids.each do |rowid|
        # This *is* an N+1 query, but:
        #  - N+1 penalty is way less with SQLite
        #  - N is relatively small (it's Jekyll post count)
        #  - This is an easy way to work around rowid not being a real column that ActiveRecord knows about.
        posts_by_rowid[rowid] = Models::Post.select(:relative_path).find_by(rowid: rowid)
      end

      related_posts = rowids.map do |rowid|
        relative_path = posts_by_rowid[rowid]['relative_path']
        @indexed_posts[relative_path]
      end

      post.data['ai_related_posts'] = related_posts
    end

    def embedding_for(post)
      Jekyll.logger.info "[ai_related_posts] Fetching embedding for #{post.relative_path}"
      input = "Title: #{post.data['title']}"
      unless post.data['categories'].empty?
        input += "; Categories: #{post.data['categories'].join(', ')}"
      end
      unless post.data['tags'].empty?
        input += "; Tags: #{post.data['tags'].join(', ')}"
      end

      @embeddings_fetcher.embedding_for(input)
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
          post_embedding(#{OpenAiEmbeddings::DIMENSIONS})
        );
      SQL
      ActiveRecord::Base.connection.execute(create_vss_posts)

      Jekyll.logger.debug("ai_related_posts db setup complete")
    end
  end
end
