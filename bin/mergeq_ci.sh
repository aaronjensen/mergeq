#!/bin/bash

# script/mergeq_ci
#
# This is the other half of script/mergeq. This script is only run on TeamCity.
# The purpose of this script is to reconcile the attempted merge with where
# the target branch actually is. It does this with some nasty hackery involving
# rewriting the .git/MERGE_HEAD.
#
# This also reconciles BRANCH_CHANGES, delegating to another script to merge
# them into CHANGELOG.md when merging into master
#
# It has two modes, one is to do the merge, run before the build, the other is
# to push, which is run after the build. I'm not really sure why it needs
# to handle the push, I don't think it does anything special.

set -e

action=$1
target_branch=$2

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

project_dir=".mergeq"
hooks_dir="$project_dir/hooks"

function run_hook {
  hook_name=$1
  hook="$hooks_dir/$hook_name"

  [[ -f $hook ]] || return 0

  status "Running CI hook: $hook_name..."

  eval "$hook \"$target_branch\""
  [[ $? -eq 0 ]] || exit $?
}

function print_usage_and_exit {
  echo "Usage: $0 <merge|push> <target-branch>"
  exit 1
}

function status {
  echo "// $1"
}

function checkout_target_branch {
  status "Checking out $target_branch..."
  git fetch origin $target_branch
  git checkout -q -f FETCH_HEAD

  status "Cleaning up working directory..."
  git reset --hard
  git clean -df
}

function merge_branch_into_target_branch {
  # This ends up looking like a new merge regardless
  # of whether or not we can fast forward merge.
  # and it copies over any merge conflict resolutions.
  # It's clearly black magic.
  status "Merging into $target_branch..."
  git merge --no-ff --no-commit $head
  echo `git rev-parse $head^2` > .git/MERGE_HEAD
}

function commit_merge {
  message=`git log -1 --pretty=%s $head`

  status "Committing merge ($message)..."
  git commit -C $head --signoff
}

function reset_and_exit_if_we_have_already_been_merged {
  set +e
  git diff --quiet FETCH_HEAD
  if [ $? -eq 0 ]
  then
    echo "
**********************************************************

 This branch has already been merged into $target_branch

**********************************************************"
    git reset --hard FETCH_HEAD
    exit 0
  fi
  set -e
}

function merge {
  head=`git rev-parse HEAD^2`

  checkout_target_branch
  merge_branch_into_target_branch

  run_hook "after_ci_merge"

  reset_and_exit_if_we_have_already_been_merged
  commit_merge
}

function push {
  status "Pushing to $target_branch..."
  git push origin HEAD:$target_branch

  run_hook "after_ci_push" # delete_feature_branch
}

function validate_parameters {
  if [ "$target_branch" = "" ] ; then
    print_usage_and_exit
  fi
}

validate_parameters

run_hook "before_ci_startup" # check_dependencies

if [ "$action" = "merge" ] ; then
  merge
elif [ "$action" = "push" ] ; then
  push
else
  print_usage_and_exit
fi
