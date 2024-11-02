# Jekyll AI Related Posts 🪄

Rubygems: [jekyll_ai_related_posts](https://rubygems.org/gems/jekyll_ai_related_posts)

Jekyll ships with functionality that populates
[related_posts](https://jekyllrb.com/docs/variables/) with the ten most recent
posts. If you install
[classifier_reborn](https://jekyll.github.io/classifier-reborn/) and use the
`--lsi` option, Jekyll will populate `related_posts` using latent semantic
indexing. 

**Using AI is a much better approach.** Latent semantic indexing seems
promising, but in practice requires libraries like Numo or GSL that are tricky
to install, and still produces mediocre results. In contrast, OpenAI offers an
embeddings API that allows us to easily get the embedding vector (in one of
OpenAI's models) of some text. We can use these vectors to compute related
posts with the accuracy of OpenAI's models (or any other LLM, for that matter).

### Used in Production at

- [MikeKasberg.com](https://www.mikekasberg.com)

(Feel free to open a PR to add your website if you're using this gem in
production!)

## Installation

Jekyll AI Related Posts is a [Jekyll
plugin](https://jekyllrb.com/docs/plugins/installation/). It can be installed
using any Jekyll plugin installation method. For example, in your `_config.yml`:

```yaml
plugins:
  - jekyll_ai_related_posts
```

You should also ignore the cache files that this plugin generates. (This will
help avoid a regeneration loop when using `jekyll serve`.)

```yaml
exclude:
  - .ai_related_posts_cache.sqlite3
  - .ai_related_posts_cache.sqlite3-journal
```


## Configuration

All config for this plugin sits under a top-level `ai_related_posts` key in
Jekyll's `_config.yml`.

The only required config is `openai_api_key` -- we need to authenticate to the
API to fetch embedding vectors.

- **openai_api_key** Your OpenAI API key, used to fetch embeddings.
- **fetch_enabled** (optional, default `true`). If true, fetch embeddings. If
  false, don't fetch embeddings. If this is a string (like `prod`), fetch
  embeddings only when the `JEKYLL_ENV` environment variable is equal to the
  string. (This is useful if you want to reduce API costs by only fetching
  embeddings on production builds.)

### Example Config

```yaml
ai_related_posts:
  openai_api_key: sk-proj-abc123
  fetch_enabled: prod
```

## Usage

When the plugin is installed and configured, it will populate an
`ai_related_posts` key in the post data for all posts. Here's an example of how
to use it:

```liquid
<h2>Related Posts</h2>
<ul>
  {% for post in page.ai_related_posts limit:3 %}
    <li><a href="{{ post.url }}">{{ post.title }}</a></li>
  {% endfor %}
</ul>
```

### First Run

The first time the plugin runs, it will fetch embeddings for all your posts.
Based on some light testing, this took me 0.5 sec per post, or about 50 sec for
a blog with 100 posts. All subsequent runs will be faster since embeddings will
be cached.

### Performance

On an example blog with ~100 posts, this plugin produces more accurate results
than classifier-reborn (LSI) in about the same amount of time. See [this blog
post](https://www.mikekasberg.com/blog/2024/04/23/better-related-posts-in-jekyll-using-ai.html)
for details.

### Cost

The API costs to use this plugin with OpenAI's API are minimal. I ran this
plugin for all 84 posts on [mikekasberg.com](https://www.mikekasberg.com) for
$0.00 in API fees (1,277 tokens on the text-embedding-3-small model). (Your
results may vary, but should remain inexpensive.)

### Upgrading from Built-In Related Posts

If you're already using Jekyll's built-in `site.related_posts` and you want to
upgrade to AI related posts:

- Install the plugin.
- Replace `site.related_posts` with `page.ai_related_posts` in your templates.
- If you were using LSI, stop. It's no longer necessary. Don't pass the `--lsi`
  option to the `jekyll` command. You can remove the `classifier-reborn` gem and
  its dependencies (Numo).

### Cache File (.ai_related_posts_cache.sqlite3)

This plugin will cache embeddings in `.ai_related_posts_cache.sqlite3` in your
Jekyll source root (typically the root of your project directory). The file
itself is a SQLite database file. For most cases, I'd recommend adding this file
to your `.gitignore` since it's a binary cache file. However, you _may_ choose
to check it in to git if, for example, you want to share cached embeddings
across many machines (and are willing to check in a binary file on the order of
1-10Mb to do so). If the file is not present, it will be re-created and
embeddings will be fetched from the API (which may result in higher API usage
fees if done frequently).

## How It Works

Jekyll AI Related Posts is implemented as a Jekyll Generator plugin. During the
build process, the plugin will call the [OpenAI Embeddings
API](https://platform.openai.com/docs/guides/embeddings) to fetch the vector
embedding for a string containing the title, tags, and categories of your
article. It's not necessary to use the full post text, in most cases the title
and tags produce very accurate results because the LLM knows when topics are
related even if they never use identical words. This is also why the LLM
produces better results than LSI. These vector embeddings are cached in a SQLite
database. To query for related posts, we query the cached vectors using the
[sqlite-vss](https://github.com/asg017/sqlite-vss) plugin.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and the created tag, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/mkasberg/jekyll_ai_related_posts.

