#!/bin/bash

# Pulls the latest commit and restores the executable bit on every tracked script.
# Safe to re-run; it makes no change when the clone is already up to date.

set -u

script_dir="$(dirname "$(readlink -f "$0")")"
cd "$script_dir" || exit 1

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: $script_dir is not a git repository."
  exit 1
fi

printf "\n"
echo "Deploying server_scripts in $script_dir"

# Refuse to pull over edits made directly on the host so nothing is lost. Mode-only
# changes are ignored because this script rewrites them anyway, and untracked files are
# left alone because a fast-forward pull cannot clobber them.
DIRTY=$(git -c core.fileMode=false status --porcelain --untracked-files=no)
if [ -n "$DIRTY" ]; then
  echo "Error: uncommitted changes on this host:"
  echo "$DIRTY"
  echo "Commit, stash or discard them before deploying."
  exit 1
fi

OLD_COMMIT=$(git rev-parse HEAD)

echo "Pulling from origin..."
# core.fileMode=false for the same reason as the check above: the exec bits this script
# restores would otherwise look like local changes and abort every pull after the first
if ! git -c core.fileMode=false pull --ff-only; then
  echo "Error: git pull failed. The host clone may have diverged from origin/main."
  echo "Inspect with: git log --oneline origin/main..HEAD"
  exit 1
fi

NEW_COMMIT=$(git rev-parse HEAD)

# Cron fails silently on a non-executable file, and lib/update_cron.sh refuses to
# install such entries, so the exec bit is restored on every tracked file that starts
# with a shebang. Read in a loop rather than `grep -lZ | xargs -0`, whose -Z flag means
# "decompress" on BSD grep and would pass the whole list to chmod as one argument.
echo "Restoring executable bits..."
while IFS= read -r -d '' TRACKED_FILE; do
  if [ -f "$TRACKED_FILE" ] && [ "$(head -c 2 "$TRACKED_FILE" 2>/dev/null)" = '#!' ]; then
    chmod +x "$TRACKED_FILE"
  fi
done < <(git ls-files -z)

MISSING_CREDS=""
for CRED_FILE in creds/duplicity.sh creds/telegram.sh; do
  if [ ! -f "$CRED_FILE" ]; then
    MISSING_CREDS+="  $CRED_FILE (copy from ${CRED_FILE%.sh}_template.sh and fill in the secrets)\n"
  else
    chmod 600 "$CRED_FILE"
  fi
done

printf "\n"
if [ "$OLD_COMMIT" = "$NEW_COMMIT" ]; then
  echo "Already up to date at $(git log -1 --oneline)"
else
  echo "Updated to $(git log -1 --oneline)"
  echo "Changed files:"
  git --no-pager diff --name-only "$OLD_COMMIT" "$NEW_COMMIT" | sed 's/^/  /'
fi

if [ -n "$MISSING_CREDS" ]; then
  printf "\nWarning: missing credential files, dependent scripts will fail:\n"
  printf "%b" "$MISSING_CREDS"
fi

printf "\nDeploy finished. Re-run the host's cron script to apply schedule changes, e.g.:\n"
echo "  $script_dir/wmj/cron_prod_wmj.sh"
echo "  $script_dir/flux/cron_prod_flux.sh"
exit 0
