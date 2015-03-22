#!/usr/bin/env bash

# script/mergeq
#
# This starts a "merge" build on your CI server. Rather than allowing untested
# merges, we first run tests on the merge and then push the merge to the
# respective branch. It does this by making use of a queue branch (not
# a real term, don't bother googling it) which is basically a branch
# for which the HEAD and each HEAD^ is a "Queueing merge" commit whose
# HEAD^2 is the the actual merge we will be testing.
#
# For example, this is merge/integration:
#
# *   25bc0e2 - Queuing merge: feature/warning-when-inviting-group-members-not-in-org into integration (5 days ago) <Shaun Dern>
# |\
# | *   9a6ffe1 - Merge feature/warning-when-inviting-group-members-not-in-org into integration (5 days ago) <Shaun Dern>
# | |\
# | | * edee6e3 - set html of target node vs text in remote_form_msg (5 days ago) <Shaun Dern>
# | | * 14c44bd - Remove Warning: prefix to warning localeapp copy (6 days ago) <Shaun Dern>
# * | |   bc31325 - Queuing merge: feature/hide-activity-feed-from-anonymous-users into integration (6 days ago) <Cassie Schmitz>
# |\ \ \
# | * \ \   c3fce08 - Merge feature/hide-activity-feed-from-anonymous-users into integration (6 days ago) <Cassie Schmitz>
#
# In the above example, the build agent will:
#  * take 9a6ffe1 and attempt to merge that to integration
#  * run tests
#  * if the tests pass, it will push the merge.
#
# Pushing the merge is handled by the mergeq_ci executable.
#
# The script will have the user do the merge locally so that they can resolve
# any merge conflicts. The user must do script/mergeq --continue after resolving
# conflicts and committing the merge.
#
# If new merge conflicts appear on the agent due to another branch being
# merged in ahead of the one they are merging, the build will fail.

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
target_branch=$1
merge_branch=${2:-"merge/$target_branch"}
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
cyan='\033[0;36m'
blue='\033[0;34m'
default='\033[0m'

project_dir=".mergeq"
hooks_dir="$project_dir/hooks"
merging_file="$project_dir/merging"

function validate_parameters {
  if [ -f $merging_file ] ; then
    echo -e "${red}It looks like you're in the middle of a merge.${default}
If so, try ${blue}mergeq --continue${default}
If not, delete the ${blue}$merging_file${default} file and try again."
    exit 1
  fi
  if [ "$target_branch" = "" ] ; then
    print_usage_and_exit
  fi
}

function print_usage_and_exit {
  echo -e "Usage: ${blue}mergeq <target-branch> [merge-branch]${default}"
  exit 1
}

function status {
  echo -e "${cyan}// $1${default}"
}

function exit_if_local_mods {
  if [ ! -z "$(git status --porcelain)" ] ; then
    status "Local modifications detected. Cannot push."
    git status -s
    exit 1
  fi

  return 0
}

# example: run_hook after
function run_hook {
  hook_name=$1
  hook="$hooks_dir/$hook_name"

  [[ -f $hook ]] || return 0

  status "Running hook: $hook_name..."

  eval "$hook \"$target_branch\" \"$merge_branch\""
  [[ $? -eq 0 ]] || exit $?
}

function merge_failed {
  echo -e "${yellow}Doh. Your merge has conflicts, but don't worry:${default}"
  echo
  echo 1. Fix your merge conflicts
  echo 2. Commit them
  echo -e "3. Run ${blue}mergeq --continue${default}"

  exit 1
}

function checkout_target_branch {
  status "Checking out $target_branch..."

  git fetch origin $target_branch
  git checkout -q FETCH_HEAD
  git reset --hard
  git clean -f
}

function cleanup {
  git checkout -q $branch
  rm $merging_file

  run_hook "after_cleanup"
}

function try_to_merge {
  status "Merging $branch into $target_branch"

  git merge --no-ff $branch -m "Merge $branch into $target_branch" || merge_failed
}

function write_temp_file {
  status "Writing temp file..."
  echo "$branch;$merge_branch;$target_branch" > $merging_file
}

function start_merge {
  status "Starting merge..."
  set -e

  exit_if_local_mods

  run_hook "before_merge"

  branch=`git rev-parse --abbrev-ref HEAD`

  checkout_target_branch
  write_temp_file
  try_to_merge

  continue_merge
}

function push_failed {
  status "Your push failed, someone may have beat you. Try again?"
}

function exit_if_we_have_already_been_merged {
  set +e
  git fetch origin $target_branch
  git diff --quiet FETCH_HEAD
  if [ $? -eq 0 ]
  then
    echo "
**********************************************************

 This branch has already been merged into $target_branch

**********************************************************"
    cleanup
    exit 0
  fi
  set -e
}

function push_to_merge_branch {
  current=`git rev-parse HEAD`

  status "Merging into $merge_branch"
  git fetch origin $merge_branch
  git checkout -q FETCH_HEAD
  git merge --no-ff -s ours --no-commit $current

  # make the merge branch match exactly before committing the merge
  # we do this so that bundle install will work when upgrading mergeq (ew)
  git checkout $current -- .
  echo $current > .merge
  git add .
  git commit -m "Queuing merge: $branch into $target_branch"

  status "Queuing merge by pushing $merge_branch"
  git push origin HEAD:refs/heads/$merge_branch

  if [ $? = 0 ] ; then
    run_hook "after_push"
  else
    push_failed
  fi
}

function continue_merge {
  exit_if_local_mods
  exit_if_we_have_already_been_merged
  push_to_merge_branch

  cleanup
  echo -e "${green}// Done!${default}"
}

if [ "$target_branch" = "--continue" ] ; then
  if [ -f $merging_file ] ; then
    IFS=';' read -ra branches < $merging_file
    branch=${branches[0]}
    merge_branch=${branches[1]}
    target_branch=${branches[2]}

    status "Continuing merge..."
    continue_merge
  else
    echo -e "
${yellow}**********************************************************${default}

 It doesn't look like you're in the middle of a merge.
 Try ${blue}mergeq <branch name>${default} to start one

${yellow}**********************************************************${default}"
    exit 1
  fi
else
  validate_parameters
  start_merge
fi
