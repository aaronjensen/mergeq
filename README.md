# Mergeq

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'mergeq'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mergeq

## Usage

Add `.mergeq/merging` to your project's `.gitignore`
Create the merge target `merge/staging`


## Pausing Guard

```
function pause_guard {
  pid=$(guard_pid)
  if [[ "$pid" ]]; then
    kill -USR1 $pid
  fi
}

function guard_pid {
  ps ax | grep "[g]uard" | awk '{print $1}'
}

function unpause_guard {
  pid=$(guard_pid)
  if [[ "$pid" ]]; then
    kill -USR2 $pid
  fi
}
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
