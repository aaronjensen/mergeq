project_dir=".mergeq"
hooks_dir="$project_dir/hooks"

function run_hook {
  hook_name=$1
  hook="$hooks_dir/$hook_name"

  [[ -f $hook ]] || return 0

  status "Running hook: $hook_name..."

  eval "$hook \"$target_branch\" \"$merge_branch\""
  [[ $? -eq 0 ]] || exit $?
}
