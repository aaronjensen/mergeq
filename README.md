# Mergeq

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'mergeq'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mergeq

Setup your mergeq directory

    $ cd your_project
    $ mkdir .mergeq

Ignore the merging lock file in git

    $ echo ".mergeq/merging" >> .gitignore

Create branches that you want to make queueable. This example creates a branch called
`staging` for queuing builds.

    $ cd your_project && git checkout master
    $ git checkout -b staging
    $ git push -u origin staging
    $ git checkout -b merge/staging
    $ git push -u origin merge/staging

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
