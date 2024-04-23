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
using any plugin installation method. The recommended way is to add
`jekyll_ai_related_posts` to your Gemfile.

## Configuration

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/jekyll_ai_related_posts.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
