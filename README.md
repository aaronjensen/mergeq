# Mergeq

TODO: Write a gem description

## Installation

Setup your mergeq directory

    $ cd your_project
    $ mkdir .mergeq

Ignore the merging lock file in git

    $ echo ".mergeq/merging" >> .gitignore

Create branches that you want to make queueable. This example creates a branch called
`staging` for queuing builds.

    $ git push origin master:staging
    $ git push origin master:merge/staging

## Configuring CI

You'll need to add two steps to your CI for mergeq.

1. First step will merge before testing. 

    `%GIT_REF%` is the sha of the queue commit to merge. This will be the tip of the `merge/staging` branch and look like:

    ```
    cf629af - Queuing merge: feature/mergeq-check-acceptance into integration (8 weeks ago) <Somebody>
    ```

    `%BRANCH%` is the name of the target branch. If the queue branch is `merge/staging`, the target branch is `staging`.

    Your CI script should look something like:

    ```bash
    $ git reset --hard %GIT_REF%
    $ bin/mergeq_ci merge %BRANCH%
    ```
    
2. Then your CI should run build/tests. 
3. If successful, it should: 
    
    ```bash
    $ bin/mergeq_ci push %BRANCH%
    ```

## Hooking mergeq

You'll probably want to hook parts of mergeq as part of your build process. Examples:

* pausing zeus for the duration of mergeq to avoid churn
* cleaning up branch metadata after a CI build

All the hooks you write live in `$project_dir/.mergeq/hooks`, and therefore are on 
a per-repo basis.

*`mergeq` hooks:*

* `before_merge` - this runs before a merge happens
* `after_push` - this runs after your branch is pushed to `merge/$target`
* `after_cleanup` - this is the last thing that runs before `mergeq` exits

*`mergeq_ci` hooks:*

* `before_ci_startup` - this runs at the very beginning of the `mergeq_ci` script
* `after_ci_merge` - this runs after CI merges into the target branch
* `after_ci_push` - this runs after CI pushes the target branch back to origin

All hooks live in `$project_dir/.mergeq/hooks/$hook_name`, and need to have `chmod +x` 
to be executable.

## Example `mergeq` hook

Arguments:

* $1 - the target branch (`integration`, `master`, etc)
* $2 - the name of the merge branch (`merge/integration`, `merge/master`, etc)

Rails projects often run something like Zeus to handle fast code loading. Since `mergeq` 
does a bunch of git checkouts, we want to pause Zeus for the duration of a `mergeq` so 
it doesn't freak out.

```bash
# .mergeq/hooks/before_merge

#!/bin/bash

target_branch=$1
merge_branch=$2

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function zeus_pid {
  cat $DIR/../../tmp/zeus.pid 2> /dev/null
}

function stop_zeus {
  pid=$(zeus_pid)
  if [[ "$pid" ]]; then
    kill -USR1 $pid
  fi
}

stop_zeus
```

```bash
# .mergeq/hooks/after_cleanup

#!/bin/bash

target_branch=$1
merge_branch=$2

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function zeus_pid {
  cat $DIR/../../tmp/zeus.pid 2> /dev/null
}

function start_zeus {
  pid=$(zeus_pid)
  if [[ "$pid" ]]; then
    kill -USR2 $pid
  fi
}
```

## Example `mergeq_ci` hook

Arguments:

* $1 - the target branch (`integration`, `master`, etc)

Say we want to delete our feature branch from GitHub after a successful merge+push to
`origin/master`. We can hook `after_ci_push` to achieve this.

```bash
# .mergeq/hooks/after_ci_push

#!/bin/bash

target_branch=$1

function delete_feature_branch {
  if [ "$target_branch" = "master" ]
  then
    git ls-remote --heads origin | grep `git rev-parse HEAD^2` | cut -f2 -s | xargs -I {} git push origin :{}; true
  fi
}

delete_feature_branch
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
