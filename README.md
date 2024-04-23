# Jekyll AI Related Posts 🪄

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

## Installation

Jekyll AI Related Posts is a [Jekyll
plugin](https://jekyllrb.com/docs/plugins/installation/). It can be installed
using any Jekyll plugin installation method.

## Configuration

All config for this plugin sits under a top-level `ai_related_posts` key.

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
  openai_api_key: abc-123
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

### Upgrading from Built-In Related Posts

If you're already using Jekyll's built-in `site.related_posts` and you want to
upgrade to AI related posts:

- Install the plugin.
- Replace `site.related_posts` with `page.ai_related_posts` in your templates.
- If you were using LSI, stop. It's no longer necessary. Don't pass the `--lsi`
  option to the `jekyll` command. You can remove the `classifier-reborn` gem and
  its dependencies (Numo).


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

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and the created tag, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/mkasberg/jekyll_ai_related_posts.

