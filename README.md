# server_scripts

Bash automation for the personal Linux servers: scheduled backups, disk and service
monitoring, and Telegram alerting. Each host clones this repo, runs one deploy command,
and installs its own set of cron entries.

Two host roles are covered today:

- **wmj** — the WordPress host for `watmarpjan.org`: WordPress + database backups to
  Google Drive, `/etc` backups, certbot and malware-scanner health checks.
- **flux** — a Flux node: node status, disk usage and unattended-upgrade monitoring.

## Deploy

On the host, as the user that owns the clone (e.g. `wmj` or `flux`):

```bash
~/server_scripts/deploy.sh
```

`deploy.sh` is idempotent and does everything a deploy needs:

1. **Refuses to run on a dirty clone.** Aborts if there are uncommitted changes to
   tracked files, so edits made directly on the host are never silently overwritten.
   Permission-only and untracked changes are ignored — neither is at risk from a
   fast-forward pull.
2. **`git pull --ff-only`.** Fast-forwards, and aborts instead of creating a merge
   commit if the host clone has diverged from `origin/main`.
3. **Restores the executable bit.** It walks every *tracked* file and `chmod +x`es the
   ones whose first two bytes are `#!`. This catches `.sh` files *and* extension-less
   scripts such as `wmj/cron_qa_wmj`, while skipping `LICENSE` and `*.md`.
4. **Checks the credentials.** Warns if `creds/duplicity.sh` or `creds/telegram.sh` is
   missing (both are gitignored, see [First-time setup](#first-time-setup-on-a-new-host))
   and tightens the existing ones to `600`.
5. **Reports what changed.** Prints the old → new commit and the list of changed files,
   or says the host was already up to date.

Step 3 is deliberately broad: it also marks `creds/*_template.sh` and `wmj/archive/*`
executable even though nothing runs them. That is harmless, and the simplicity is worth
more than an exclusion list that would need maintaining.

Add a shortcut to `~/.bashrc` on the host if you prefer:

```bash
alias deploy-scripts='~/server_scripts/deploy.sh'
```

Deploying does **not** re-install cron entries. Re-run the host's `cron_prod_*.sh` after
a schedule change — see [Cron schedules](#cron-schedules).

### Deploying without the script

The equivalent one-liner, for a host that has not pulled `deploy.sh` yet:

```bash
cd ~/server_scripts && git pull --ff-only && git ls-files -z | xargs -0 grep -l --null '^#!' | xargs -0 chmod +x
```

Use `--null`, not the shorter `-Z`: on GNU grep they are the same, but on BSD grep
(macOS) `-Z` means *decompress*, which silently hands the whole file list to `chmod` as
a single argument.

### Post-deploy checklist

- `git log -1 --oneline` — the host is on the commit you expect.
- `git status --short` — no unexpected local modifications (permission-only changes
  should disappear once the exec bit is tracked upstream).
- Re-run the relevant `cron_prod_*.sh` if schedules changed; it is idempotent, and
  `lib/update_cron.sh` replaces existing entries for the same script, including renamed
  or rescheduled ones.
- Check `~/server_scripts_logs/*.error.log` after the next scheduled run.

## Why the `chmod` is needed at all

`lib/update_cron.sh` refuses to install a cron entry whose target script is not
executable, because cron fails *silently* on a non-executable file and the job would
never run. Any script that loses its exec bit therefore breaks the next
`cron_prod_*.sh` run.

Git only tracks a single permission bit (`100644` = non-executable, `100755` =
executable). If a file was committed as `100644`, every `git pull` on every host will
keep producing a non-executable file — the `chmod` fixes it on the host, but the real
fix belongs in the repo.

### Permanent fix: track the exec bit in Git

Do this **once, on the workstation**, so hosts get correct permissions straight from
`git pull` and the `chmod` step becomes a no-op safety net.

Check which tracked scripts are still committed as non-executable:

```bash
git ls-files -s | awk '$1 == "100644"'
```

Mark the ones that are meant to be *run* (not merely `source`d) as executable and
commit:

```bash
git update-index --chmod=+x path/to/script.sh
git commit -m "Track exec bit on scripts"
git push
```

As of this writing the following tracked files are `100644`:

| File | Worth committing as `100755`? |
| --- | --- |
| `flux/cron_prod_root.sh` | yes — run from root's crontab |
| `wmj/cron_prod_root.sh` | yes — run from root's crontab |
| `wmj/restore/restore_backup.sh` | yes — run manually during restores |
| `wmj/temp_while_duplicity_failing/backup-rclone-etc.sh` | yes — invoked by cron |
| `wmj/temp_while_duplicity_failing/backup-rclone-wmj-org.sh` | yes — invoked by cron |
| `creds/duplicity_template.sh` | no — `source`d only |
| `creds/telegram_template.sh` | no — `source`d only |
| `wmj/archive/*` | no — historical copies |

Also confirm `core.fileMode` is left at its default (`true`) on Linux hosts, otherwise
Git ignores permission changes entirely:

```bash
git config --get core.fileMode   # expect "true" or empty
```

macOS/iCloud note: this repo lives under iCloud Drive on the workstation. iCloud can
strip exec bits locally, which is another reason to rely on `git update-index --chmod=+x`
rather than on whatever `ls -l` shows on the Mac.

### Optional: a `post-merge` hook on the host

For the case where someone runs a plain `git pull` instead of `deploy.sh`, install a
hook once per host:

```bash
cat > ~/server_scripts/.git/hooks/post-merge <<'EOF'
#!/bin/bash
cd "$(git rev-parse --show-toplevel)" || exit 1
git ls-files -z | xargs -0 grep -l --null '^#!' | xargs -0 chmod +x
EOF
chmod +x ~/server_scripts/.git/hooks/post-merge
```

Hooks live in `.git/hooks/` and are **not** versioned, so this must be repeated on each
host (and after re-cloning).

## First-time setup on a new host

```bash
git clone https://github.com/raryelcostasouza/server_scripts.git ~/server_scripts
cd ~/server_scripts
chmod +x deploy.sh && ./deploy.sh   # bootstraps the exec bits on everything else

# credentials are gitignored — create them from the templates
cp creds/duplicity_template.sh creds/duplicity.sh
cp creds/telegram_template.sh  creds/telegram.sh
chmod 600 creds/duplicity.sh creds/telegram.sh
# edit both files and fill in the real secrets
```

Then install the cron entries for the host's role:

```bash
./wmj/cron_prod_wmj.sh         # or ./flux/cron_prod_flux.sh
sudo ./wmj/cron_prod_root.sh   # root-owned jobs, where applicable
```

Verify:

```bash
crontab -l
ls -l ~/server_scripts_logs/
```

## Repository layout

```
creds/     gitignored secrets + their committed templates
lib/       shared helpers, sourced or called by the host scripts
wmj/       WordPress host: backups, cert and malware checks
flux/      Flux node: status and disk monitoring
generic/   host-agnostic checks
log/       placeholder; real logs go to ~/server_scripts_logs/
```

### `lib/` — shared helpers

| Script | Purpose | Args |
| --- | --- | --- |
| `update_cron.sh` | Installs a cron entry, replacing any prior entry for the same script. Refuses non-executable targets. | `"<cron entry>"` |
| `cron_qa_schedule.sh` | Wraps `update_cron.sh` with a fixed `*/2 * * * *` schedule for QA runs | `<script path>` |
| `vars_logging.sh` | Sets `STANDARD_LOG_FILE` / `ERROR_LOG_FILE` and redirects stdout and stderr to them | sourced |
| `create_logs_dir.sh` | Creates `~/server_scripts_logs` if missing | — |
| `clean_script_logs_older_n_days.sh` | Deletes logs older than 90 days | — |
| `send_telegram_alert.sh` | Sends a message through the Telegram bot API | `<message>` |
| `check_if_error_log_not_empty.sh` | Alerts with the log contents if the error log is non-empty | `<log file>` |
| `check_cron_entries_valid.sh` | Alerts if any script referenced by crontab is missing or non-executable | — |
| `check_required_commands.sh` | Alerts if any of the given commands is not in `PATH` | `<cmd>...` |
| `check_script_ran_recently.sh` | Alerts if no log for a script exists within N days | `<days> <script name>` |
| `check_remote_backup_freshness.sh` | Alerts if the newest file at an rclone path is older than N days | `<days> <rclone path>` |
| `check_partition_disk_usage.sh` | Alerts if a partition exceeds a usage threshold | `<partition> <threshold>` |
| `monitor_disk_usage.sh` | Runs the partition check across several partitions | `<threshold> <partition>...` |
| `monitor_logs_unattended_upgrades.sh` | Reports errors and warnings from the last 7 days of the unattended-upgrades log | — |

### `wmj/` — WordPress host

| Script | Purpose |
| --- | --- |
| `backup_wp_files_and_DB.sh` | `mysqldump` + `7za` of the WordPress files and databases, uploaded to Google Drive |
| `backup_etc_dir.sh` | duplicity backup of `/etc` to Google Drive, with cleanup and incremental logic |
| `sync_wordpress_uploads.sh` | `rclone` sync of `wp-content/uploads` to Google Drive |
| `monitor_backups_wmj.sh` | Checks backup freshness, required commands and crontab validity |
| `monitor_disk_usage_wmj.sh` | `/boot` and the LVM partition at an 80% threshold |
| `certbot_health_check.sh` | Verifies certbot and runs a renewal dry-run |
| `malware-detector-log-checker.sh` | Alerts on `INFECTION` entries in the maldet event log |
| `cron_prod_wmj.sh`, `cron_prod_root.sh`, `cron_qa_wmj` | Cron installers |
| `restore/restore_backup.sh` | Reference commands for a duplicity restore (run manually) |
| `temp_while_duplicity_failing/` | rclone-based stand-ins used while duplicity was broken |
| `archive/` | Superseded scripts, kept for reference only |

### `flux/` and `generic/`

| Script | Purpose |
| --- | --- |
| `flux/monitor_node_confirmed_status.sh` | Alerts when `flux-cli getzelnodestatus` is not `CONFIRMED` |
| `flux/monitor_disk_usage_flux.sh` | `/dev/sda1` at an 80% threshold |
| `flux/cron_prod_flux.sh`, `cron_prod_root.sh`, `cron_qa_flux.sh` | Cron installers |
| `generic/fail2ban-monitor.sh` | Alerts on bans found in the fail2ban log |

## How it works

**Logging.** Any script that sources `lib/vars_logging.sh` redirects stdout to
`~/server_scripts_logs/<script>-<timestamp>.log` and stderr to a matching
`.error.log`. `lib/clean_script_logs_older_n_days.sh` prunes anything older than 90
days. The repo's `log/` directory is only a placeholder — nothing is written there.

**Alerting.** Everything reports through `lib/send_telegram_alert.sh`, which needs
`BOT_TOKEN` and `CHAT_ID` from `creds/telegram.sh`. The usual pattern is for a job to
end with `lib/check_if_error_log_not_empty.sh "$ERROR_LOG_FILE"`, so a silent run means
a healthy run.

**Cron.** Schedules are not hand-edited with `crontab -e`; they live in the
`cron_prod_*.sh` scripts and are applied by re-running them. `lib/update_cron.sh`
removes any previous entry for the same script path before adding the new one, so
renaming or rescheduling a job will not leave a stale duplicate behind.

**Credentials.** `creds/duplicity.sh` (`PASSPHRASE`, `PASSPHRASE_ZIP`, `DUPLICITY_CMD`)
and `creds/telegram.sh` (`BOT_TOKEN`, `CHAT_ID`) are gitignored and must be created per
host from the committed `*_template.sh` files.

## Cron schedules

Installed by re-running the relevant script. QA variants (`cron_qa_*`) replace all
schedules with `*/2 * * * *` for rapid testing — never run them on a production host.

**`wmj/cron_prod_wmj.sh`** (user crontab)

| Schedule | Job |
| --- | --- |
| `0 2 * * *` | `backup_wp_files_and_DB.sh` |
| `0 0 * * 1` | `monitor_disk_usage_wmj.sh` |
| `0 6 * * 1` | `monitor_backups_wmj.sh` |
| `30 3 1 * *` | `lib/clean_script_logs_older_n_days.sh` |

**`wmj/cron_prod_root.sh`** (root crontab)

| Schedule | Job |
| --- | --- |
| `0 1 * * *` | `backup_etc_dir.sh` |
| `0 0 * * 1` | `lib/monitor_logs_unattended_upgrades.sh` |
| `30 3 1 * *` | `lib/clean_script_logs_older_n_days.sh` |

**`flux/cron_prod_flux.sh`** (user crontab)

| Schedule | Job |
| --- | --- |
| `0 * * * *` | `monitor_node_confirmed_status.sh` |
| `0 0 * * *` | `monitor_disk_usage_flux.sh` |
| `0 0 * * *` | `lib/monitor_logs_unattended_upgrades.sh` |
| `30 3 1 * *` | `lib/clean_script_logs_older_n_days.sh` |

**`flux/cron_prod_root.sh`** (root crontab)

| Schedule | Job |
| --- | --- |
| `0 0 * * 1` | `lib/monitor_logs_unattended_upgrades.sh` |
| `30 3 1 * *` | `lib/clean_script_logs_older_n_days.sh` |

> Note: the log cleanup uses `30 3 1 * *`, not `30 3 1 * 1`. When both the day-of-month
> and day-of-week fields are restricted, cron ORs them, so `30 3 1 * 1` would fire on
> the 1st of every month *and* every Monday — 63 times a year instead of 12. "First
> Monday of the month" is not expressible in standard cron; it needs a guard in the
> command, e.g. `30 3 * * 1 [ "$(date +\%d)" -le 07 ] && ...`.

## External dependencies

Installed per host, not by this repo. `lib/check_required_commands.sh` is used by the
monitors to alert when one goes missing after an OS upgrade.

| Command | Used by |
| --- | --- |
| `duplicity` | `wmj/backup_etc_dir.sh`, `wmj/backup_wp_files_and_DB.sh` |
| `rclone` | the `wmj` backup and sync scripts, `check_remote_backup_freshness.sh` |
| `mysqldump`, `7za`, `tar` | `wmj/backup_wp_files_and_DB.sh` |
| `certbot` | `wmj/certbot_health_check.sh` |
| `maldet` | `wmj/malware-detector-log-checker.sh` |
| `flux-cli`, `jq` | `flux/monitor_node_confirmed_status.sh` |
| `curl` | `lib/send_telegram_alert.sh` |
| `fail2ban` | `generic/fail2ban-monitor.sh` |

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Error: <path> is not executable` from `update_cron.sh` | exec bit missing | re-run `deploy.sh`; then track the bit upstream |
| `deploy.sh` aborts with "uncommitted changes on this host" | a tracked file was edited directly on the host | review with `git diff`, then commit and push the change, or `git checkout -- <file>` to discard it |
| `git pull --ff-only` fails | host clone diverged (local edits committed on the host) | inspect with `git log --oneline origin/main..HEAD`, then `git stash` / `git reset --hard origin/main` once you are sure nothing is lost |
| `xargs: chmod: File name too long` | the manual one-liner used `grep -lZ` on BSD grep | use `grep -l --null`, or just run `deploy.sh` |
| Cron job silently does nothing | non-executable target, or missing `creds/*.sh` | check `~/server_scripts_logs/*.error.log` |
| No Telegram alerts at all | `creds/telegram.sh` missing or wrong `BOT_TOKEN` / `CHAT_ID` | run `lib/send_telegram_alert.sh "test"` by hand |

## License

MIT — see [LICENSE](LICENSE).
