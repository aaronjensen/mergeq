# mergeq

![mergeq explanatory comic](http://i.imgur.com/2iDn1qu.png)

Have you ever broken the build? Have you ever had to wait for a teammate to fix
the build so that you can deploy your change that won't break the build?

mergeq can help by only allowing branches that pass CI to get merged into
`master` or `develop` or whatever. If your build doesn't pass, the branch you
are trying to merge into doesn't change and no one else is affected.

mergeq is an implementation of the "pre-tested commit" pattern that is:

* **Robust**--two people can merge at the same time and, as long as their branches do not conflict with one another, they both get a chance to get merged in safely.
* **Continuous Integration server independent**--as long as your server has permission to push to your repo and can support running only one build at a time, it should work.
* **Flexible**--there are [hooks](#hooking-mergeq) to support safety checks or post build notifications.
* **Easy to setup**--no additional intermediary repository, no additional infratructure
* **Battle tested**--we have been using it for over 3 years with great success.

If you want strict **pre-reviewed**, as well as pre-tested commits, and you don't mind additional infrastructure, you can check out [Gerrit](https://www.gerritcodereview.com/).

## How it works

Say you have a branch, `feature` that you want to merge into `master`. Instead
of merging directly to `master`, you run `mergeq master`. `mergeq` will fetch
the latest `master` from `origin` and merge your branch into it. You can
resolve any merge conflicts and then `mergeq` will push the merged branch to a
special branch called `merge/master`. Your CI server will pick up changes from
that branch, run the build, and if it passes, push the merge to `master`. If it
fails, it will do nothing else and your failing build won't get in anyone's
way. Merge away!

## Remote Installation (quick)

    $ cd your_project
    $ bash <(curl -s https://raw.githubusercontent.com/aaronjensen/mergeq/master/bin/mergeq_remote_install)

You can always re-run this script to upgrade your project's copy of mergeq.

If you don't trust `curl`, which is totally understandable, just do this:

    $ curl -o mergeq_remote_install https://raw.githubusercontent.com/aaronjensen/mergeq/master/bin/mergeq_remote_install
    $ chmod +x mergeq_remote_install

    # open the install script and audit it for security

    $ ./mergeq_remote_install

Running `mergeq_remote_install` will add a few files, so be sure to commit them to your repo:

    $ git status
    $ git add .
    $ git commit -m "Added mergeq to the project"

Next, create branches that you want to make queueable. This example creates a branch 
called `staging` for queuing builds.

    $ git push origin master:staging
    $ git push origin master:merge/staging

## Configuring CI

There are a few things to take into account when using mergeq on your CI server.

* Only one build per branch can run at once. With TeamCity, you can "Limit the number of simultaneously running builds" to 1.
* You need to run a build for every push rather than just the most recent. With TeamCity, we do this by disabling VCS build triggering and starting the build automatically via a webhook like this:
    
    ```bash
    curl --insecure "https://user:pass@teamcity.server.com/httpAuth/action.html?add2Queue=$build_id&name=GIT_REF&value=$git_ref"
    ```

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
