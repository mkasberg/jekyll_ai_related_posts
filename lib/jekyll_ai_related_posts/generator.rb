# frozen_string_literal: true

require "active_record"
require "sqlite3"
require "sqlite_vss"
require "jekyll"
require "json"

module JekyllAiRelatedPosts
  class Generator < Jekyll::Generator
    def generate(site)
      Jekyll.logger.debug "AI Related Posts:", "Generating related posts..."

      @site = site
      @stats = {
        cache_hits: 0,
        cache_misses: 0
      }
      @embeddings_fetcher = new_fetcher if fetch_enabled?

      setup_database

      @indexed_posts = {}
      site.posts.docs.each do |p|
        @indexed_posts[p.relative_path] = p
      end

      if fetch_enabled?
        validate_cache_metadata

        @site.posts.docs.each do |p|
          ensure_embedding_cached(p)
        end

        @site.posts.docs.each do |p|
          find_related(p)
        end
        Jekyll.logger.info "AI Related Posts:", "Found #{@stats[:cache_hits]} cached embeddings; fetched #{@stats[:cache_misses]}"
      else
        Jekyll.logger.info "AI Related Posts:", "Fetch disabled. Using cached related posts data."

        @site.posts.docs.each do |p|
          fallback_generate_related(p)
        end

        case @stats[:cache_misses]
        when 0
          Jekyll.logger.info "AI Related Posts:", "Found #{@stats[:cache_hits]} cached embeddings; all embeddings cached"
        when 1
          Jekyll.logger.info "AI Related Posts:", "Found #{@stats[:cache_hits]} cached embeddings; skipped 1 fetch"
        else
          Jekyll.logger.info "AI Related Posts:", "Found #{@stats[:cache_hits]} cached embeddings; skipped #{@stats[:cache_misses]} fetches"
        end
      end

      Jekyll.logger.debug "AI Related Posts:", "Done generating related posts"
    end

    private

    def fetch_enabled?
      enabled = true
      if @site.config["ai_related_posts"]["fetch_enabled"].is_a? String
        enabled = ENV["JEKYLL_ENV"] == @site.config["ai_related_posts"]["fetch_enabled"]
      elsif [ true, false ].include? @site.config["ai_related_posts"]["fetch_enabled"]
        enabled = @site.config["ai_related_posts"]["fetch_enabled"]
      end

      enabled
    end

    def fallback_generate_related(post)
      existing = Models::Post.find_by(relative_path: post.relative_path)
      if existing.nil?
        @stats[:cache_misses] += 1
        post.data["ai_related_posts"] = post.related_posts
      else
        if existing.embedding_text == embedding_text(post)
          @stats[:cache_hits] += 1
        else
          @stats[:cache_misses] += 1
        end
        find_related(post)
      end
    end

    def new_fetcher
      case @site.config["ai_related_posts"]["embeddings_source"]
      when "mock"
        model = @site.config["ai_related_posts"]["model"]
        dimensions = @site.config["ai_related_posts"]["dimensions"]
        MockEmbeddings.new(model: model, dimensions: dimensions)
      else
        api_key = @site.config["ai_related_posts"]["api_key"] ||
          @site.config["ai_related_posts"]["openai_api_key"]
        api_url = @site.config["ai_related_posts"]["api_url"]
        model = @site.config["ai_related_posts"]["model"]
        ApiEmbeddings.new(api_key, api_url: api_url, model: model)
      end
    end

    def ensure_embedding_cached(post)
      existing = Models::Post.find_by(relative_path: post.relative_path)

      # Clear cache if post has been updated
      if !existing.nil? && existing.embedding_text != embedding_text(post)
        sql = "DELETE FROM vss_posts WHERE rowid = (SELECT rowid FROM posts WHERE relative_path = :relative_path);"
        ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql([ sql,
                                                                               { relative_path: post.relative_path } ]))
        existing.destroy!
        existing = nil
      end

      if existing.nil?
        @stats[:cache_misses] += 1

        Models::Post.create!(
          relative_path: post.relative_path,
          embedding_text: embedding_text(post),
          embedding: embedding_for(post).to_json
        )

        sql = <<-SQL
            INSERT INTO vss_posts (rowid, post_embedding)
              SELECT rowid, embedding FROM posts WHERE relative_path = :relative_path;
        SQL
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql([ sql, { relative_path: post.relative_path } ])
        )
      else
        @stats[:cache_hits] += 1
      end
    end

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

      results = ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql([ sql, { relative_path: post.relative_path } ])
      )
      # The first result is the post itself, with a distance of 0.
      rowids = results.sort_by { |r| r["distance"] }.drop(1).first(10).map { |r| r["rowid"] }

      posts_by_rowid = {}
      rowids.each do |rowid|
        # This *is* an N+1 query, but:
        #  - N+1 penalty is way less with SQLite
        #  - N is relatively small (it's Jekyll post count)
        #  - This is an easy way to work around rowid not being a real column that ActiveRecord knows about.
        posts_by_rowid[rowid] = Models::Post.select(:relative_path).find_by(rowid: rowid)
      end

      related_posts = rowids.map do |rowid|
        relative_path = posts_by_rowid[rowid]["relative_path"]
        @indexed_posts[relative_path]
      end

      post.data["ai_related_posts"] = related_posts
    end

    def dimensions
      @embeddings_fetcher&.dimensions || ApiEmbeddings::DEFAULT_DIMENSIONS
    end

    def model
      @embeddings_fetcher&.model || ApiEmbeddings::DEFAULT_MODEL
    end

    def embedding_text(post)
      text = "Title: #{post.data["title"]}"
      text += "; Categories: #{post.data["categories"].join(", ")}" unless post.data["categories"].empty?
      text += "; Tags: #{post.data["tags"].join(", ")}" unless post.data["tags"].empty?

      text
    end

    def embedding_for(post)
      Jekyll.logger.info "AI Related Posts:", "Fetching embedding for #{post.relative_path}"
      input = embedding_text(post)

      @embeddings_fetcher.embedding_for(input)
    end

    def setup_database
      db_path = @site.in_source_dir(".ai_related_posts_cache.sqlite3")
      if File.exist?(db_path)
        Jekyll.logger.debug "AI Related Posts:", "Found cache [.ai_related_posts_cache.sqlite3]"
      else
        Jekyll.logger.info "AI Related Posts:", "Creating cache [.ai_related_posts_cache.sqlite3]"
      end

      ActiveRecord::Base.establish_connection(
        adapter: "sqlite3",
        database: db_path
      )
      # We don't need WAL mode for this.
      ActiveRecord::Base.connection.execute("PRAGMA journal_mode=DELETE;")

      # Enable sqlite-vss vector extension
      db = ActiveRecord::Base.connection.raw_connection
      db.enable_load_extension(true)
      SqliteVss.load(db)
      db.enable_load_extension(false)

      create_posts = <<-SQL
        CREATE TABLE IF NOT EXISTS posts(
          relative_path TEXT PRIMARY KEY,
          embedding_text TEXT,
          embedding TEXT
        );
      SQL
      ActiveRecord::Base.connection.execute(create_posts)

      unless table_exists?("vss_posts")
        create_vss_posts = <<-SQL
          CREATE VIRTUAL TABLE vss_posts using vss0(
            post_embedding(#{dimensions})
          );
        SQL
        ActiveRecord::Base.connection.execute(create_vss_posts)
      end

      create_cache_metadata = <<-SQL
        CREATE TABLE IF NOT EXISTS cache_metadata(
          key TEXT PRIMARY KEY,
          value TEXT
        );
      SQL
      ActiveRecord::Base.connection.execute(create_cache_metadata)

      Jekyll.logger.debug "AI Related Posts:", "DB setup complete"
    end

    def table_exists?(name)
      ActiveRecord::Base.connection.table_exists?(name)
    end

    def validate_cache_metadata
      model = @embeddings_fetcher&.model || ApiEmbeddings::DEFAULT_MODEL

      stored_model = ActiveRecord::Base.connection.execute(
        "SELECT value FROM cache_metadata WHERE key = 'model';"
      ).first

      if stored_model && stored_model["value"] != model
        Jekyll.logger.error "AI Related Posts:", "Cache model mismatch!"
        Jekyll.logger.error "AI Related Posts:", "  Configured model: #{model}"
        Jekyll.logger.error "AI Related Posts:", "  Cached model:     #{stored_model["value"]}"
        Jekyll.logger.error "AI Related Posts:", "Either update your config to match the cached model, or delete the cache file (.ai_related_posts_cache.sqlite3) and it will be regenerated."
        raise Error, "Cache model mismatch: configured=#{model}, cached=#{stored_model["value"]}"
      end

      # Store/update metadata if not present
      if stored_model.nil?
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql([ "INSERT INTO cache_metadata (key, value) VALUES ('model', ?);", model ])
        )
      end
    end
  end
end
