#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

# ======================== Config ========================
BASE="${BASE:-/home/ubuntu/treehole}"
INCOMING="${INCOMING:-$BASE/incoming}"
RELEASES="${RELEASES:-$BASE/releases}"
BACKUPS="${BACKUPS:-$BASE/backups}"
CURRENT="${CURRENT:-$BASE/current}"
SERVICE="${SERVICE:-treehole}"
SITE_HOST="${SITE_HOST:-zhixing.xidian.edu.cn}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:8080/api}"
HEALTH_RETRIES="${HEALTH_RETRIES:-30}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-2}"
KEEP_RELEASES="${KEEP_RELEASES:-8}"
LOCK_FILE="${LOCK_FILE:-/run/lock/treehole-deploy.lock}"

# Optional positional argument: exact package path.
REQUESTED_PACKAGE="${1:-}"

# ======================== Runtime state ========================
DEPLOY_ID="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_FILE="$BACKUPS/deployment-check-$DEPLOY_ID.txt"
LOG_FILE="$BACKUPS/deployment-$DEPLOY_ID.log"
STAGING=""
PACKAGE=""
PACKAGE_SHA256=""
CHECKSUM_SOURCE="not-checked"
MANIFEST_VERIFIED="not-checked"
VERIFY_DEFERRED=0
NEW_RELEASE=""
OLD_RELEASE=""
ACTIVATED_RELEASE=""
RUNNING_RELEASE=""
ACTIVATED=0
ROLLBACK_DONE=0
LAST_ERROR=""

mkdir -p "$INCOMING" "$RELEASES" "$BACKUPS"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$*"
}

write_report() {
    local result="$1"
    local restored_release="${2:-}"

    cat > "$REPORT_FILE" <<REPORT
DEPLOYMENT_RESULT=$result
PACKAGE=$PACKAGE
PACKAGE_SHA256=$PACKAGE_SHA256
CHECKSUM_SOURCE=$CHECKSUM_SOURCE
MANIFEST_VERIFIED=$MANIFEST_VERIFIED
ATTEMPTED_RELEASE=$NEW_RELEASE
ACTIVATED_RELEASE=$ACTIVATED_RELEASE
RUNNING_RELEASE=$RUNNING_RELEASE
PREVIOUS_RELEASE=$OLD_RELEASE
RESTORED_RELEASE=$restored_release
SERVICE=$SERVICE
HEALTH_URL=$HEALTH_URL
LOG_FILE=$LOG_FILE
TIME_UTC=$(date -u +%Y%m%dT%H%M%SZ)
REPORT
}

cleanup_staging() {
    if [[ -n "$STAGING" && -e "$STAGING" ]]; then
        rm -rf -- "$STAGING"
    fi
}

rollback() {
    local reason="$1"

    if (( ROLLBACK_DONE )); then
        return 0
    fi
    ROLLBACK_DONE=1
    set +e

    log "ERROR: $reason"

    if (( ACTIVATED )); then
        log "Rolling back current to: ${OLD_RELEASE:-<none>}"
        systemctl stop "$SERVICE" || true

        if [[ -n "$OLD_RELEASE" && -d "$OLD_RELEASE" ]]; then
            local rollback_link="$BASE/.current-rollback-$$"
            rm -f -- "$rollback_link"
            ln -s -- "$OLD_RELEASE" "$rollback_link"
            mv -Tf -- "$rollback_link" "$CURRENT"
            systemctl start "$SERVICE" || true
            write_report "FAILED_AND_ROLLED_BACK" "$OLD_RELEASE"
        else
            rm -f -- "$CURRENT"
            write_report "FAILED_AFTER_SWITCH_NO_ROLLBACK_TARGET"
        fi
    else
        write_report "FAILED_BEFORE_SWITCH"
    fi

    cleanup_staging
    log "Deployment failed. Report: $REPORT_FILE"
    log "Log: $LOG_FILE"
}

on_error() {
    local rc=$?
    local line="${BASH_LINENO[0]:-unknown}"
    LAST_ERROR="command failed at line $line (exit $rc)"
    return "$rc"
}

on_exit() {
    local rc=$?
    trap - ERR EXIT

    if (( rc != 0 )); then
        rollback "${LAST_ERROR:-deployment exited with status $rc}"
    fi

    cleanup_staging
    exit "$rc"
}

trap on_error ERR
trap on_exit EXIT

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        log "Missing required command: $1"
        return 1
    }
}

# ======================== Preflight ========================
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    log "Please run this script as root."
    exit 1
fi

for cmd in flock find sort tar sha256sum systemctl readlink curl stat mv ln python3; do
    require_command "$cmd"
done

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    log "Another deployment is already running: $LOCK_FILE"
    exit 1
fi

if ! systemctl cat "$SERVICE" >/dev/null 2>&1; then
    log "systemd service not found: $SERVICE"
    exit 1
fi

if [[ -e "$CURRENT" && ! -L "$CURRENT" ]]; then
    log "Refusing to deploy: $CURRENT exists but is not a symbolic link."
    log "Move that directory/file aside manually, then run again."
    exit 1
fi

OLD_RELEASE="$(readlink -f "$CURRENT" 2>/dev/null || true)"

# ======================== Select package ========================
if [[ -n "$REQUESTED_PACKAGE" ]]; then
    PACKAGE="$(readlink -f "$REQUESTED_PACKAGE")"
else
    PACKAGE="$({
        find "$INCOMING" -maxdepth 1 -type f -name 'treehole-*.tar.gz' \
            -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-
    } || true)"
fi

if [[ -z "$PACKAGE" || ! -f "$PACKAGE" ]]; then
    log "No deployment package found."
    log "Expected: $INCOMING/treehole-*.tar.gz"
    exit 1
fi

case "$PACKAGE" in
    "$INCOMING"/*) ;;
    *)
        log "Refusing package outside incoming directory: $PACKAGE"
        exit 1
        ;;
esac

log "Selected package: $PACKAGE"

tar --warning=no-unknown-keyword -tzf "$PACKAGE" >/dev/null
if tar --warning=no-unknown-keyword -tzf "$PACKAGE" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    log "Package contains an unsafe absolute or parent-relative path."
    exit 1
fi
PACKAGE_SHA256="$(sha256sum "$PACKAGE" | awk '{print $1}')"
log "Package SHA256: $PACKAGE_SHA256"

# ======================== Verify package checksum ========================
# The sidecar catches transport corruption before anything is extracted.
# scripts/package_release.sh writes it alongside the archive; a package that
# arrives without one is still accepted, but its transport is then unverified.
SIDECAR="$PACKAGE.sha256"
if [[ -f "$SIDECAR" ]]; then
    EXPECTED_SHA256="$(awk 'NR == 1 { print $1 }' "$SIDECAR")"

    if [[ ! "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
        log "Malformed sidecar checksum: $SIDECAR"
        exit 1
    fi

    if [[ "$EXPECTED_SHA256" != "$PACKAGE_SHA256" ]]; then
        log "Package checksum mismatch — refusing to deploy a corrupted package."
        log "Expected: $EXPECTED_SHA256"
        log "Actual:   $PACKAGE_SHA256"
        exit 1
    fi

    CHECKSUM_SOURCE="sidecar-verified"
    log "Sidecar checksum matches: $SIDECAR"
else
    CHECKSUM_SOURCE="no-sidecar"
    log "WARNING: no sidecar checksum at $SIDECAR; transport integrity unverified."
fi

# ======================== Verify release manifest ========================
# verify_release_archive.py checks every file's SHA-256 against the in-archive
# RELEASE-MANIFEST.sha256, rejects unsafe member paths and symlink/device
# members, and asserts that the files the installer needs are actually present.
# The `tar -tzf` above only proves the archive is readable, not that it is
# complete — a truncated or partially rebuilt package passes that check.
#
# Prefer the verifier from the currently active release: that is code already
# known to work, rather than code shipped by the package being judged. Only when
# there is no active release do we fall back to the packaged copy, which means
# waiting until after extraction.
verify_manifest() {
    local verifier="$1"
    log "Verifying release manifest with: $verifier"
    python3 "$verifier" "$PACKAGE"
}

CURRENT_VERIFIER="$CURRENT/scripts/verify_release_archive.py"
if [[ -f "$CURRENT_VERIFIER" ]]; then
    verify_manifest "$CURRENT_VERIFIER"
    MANIFEST_VERIFIED="yes (active-release verifier)"
else
    VERIFY_DEFERRED=1
    log "No verifier in the active release; deferring manifest check until after extraction."
fi

PACKAGE_NAME="$(basename "$PACKAGE" .tar.gz)"
SAFE_NAME="$(printf '%s' "$PACKAGE_NAME" | tr '+' '_' | tr -cd 'A-Za-z0-9._-')"
NEW_RELEASE="$RELEASES/${DEPLOY_ID}-${SAFE_NAME}"
STAGING="$RELEASES/.staging-${DEPLOY_ID}-$$"

if [[ -e "$NEW_RELEASE" ]]; then
    log "Release path already exists: $NEW_RELEASE"
    exit 1
fi

# ======================== Extract release ========================
log "Extracting package into staging directory."
mkdir -p "$STAGING"
tar --warning=no-unknown-keyword -xzf "$PACKAGE" -C "$STAGING" --no-same-owner

mapfile -d '' TOP_ENTRIES < <(find "$STAGING" -mindepth 1 -maxdepth 1 -print0)
if (( ${#TOP_ENTRIES[@]} == 0 )); then
    log "Package is empty."
    exit 1
elif (( ${#TOP_ENTRIES[@]} == 1 )) && [[ -d "${TOP_ENTRIES[0]}" ]]; then
    mv -- "${TOP_ENTRIES[0]}" "$NEW_RELEASE"
    rmdir "$STAGING"
    STAGING=""
else
    mv -- "$STAGING" "$NEW_RELEASE"
    STAGING=""
fi

if [[ ! -d "$NEW_RELEASE" ]]; then
    log "Release directory was not created: $NEW_RELEASE"
    exit 1
fi

if ! find "$NEW_RELEASE" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    log "Release directory is empty: $NEW_RELEASE"
    exit 1
fi

if (( VERIFY_DEFERRED )); then
    PACKAGED_VERIFIER="$NEW_RELEASE/scripts/verify_release_archive.py"

    if [[ -f "$PACKAGED_VERIFIER" ]]; then
        verify_manifest "$PACKAGED_VERIFIER"
        MANIFEST_VERIFIED="yes (packaged verifier)"
    else
        MANIFEST_VERIFIED="skipped (no verifier available)"
        log "WARNING: no verify_release_archive.py anywhere; manifest unverified."
    fi
fi

# Give the service account ownership when the unit declares User=.
SERVICE_USER="$(systemctl show "$SERVICE" -p User --value)"
SERVICE_GROUP="$(systemctl show "$SERVICE" -p Group --value)"
if [[ -n "$SERVICE_USER" && "$SERVICE_USER" != "root" ]]; then
    if id "$SERVICE_USER" >/dev/null 2>&1; then
        [[ -n "$SERVICE_GROUP" ]] || SERVICE_GROUP="$(id -gn "$SERVICE_USER")"
        chown -R "$SERVICE_USER:$SERVICE_GROUP" "$NEW_RELEASE"
    fi
fi
# The package may contain a top-level directory with mode 0700.
# Nginx runs as www-data and must be able to traverse the release
# directory and read the compiled web files.
chmod 0755 "$NEW_RELEASE"

if [[ ! -d "$NEW_RELEASE/web" ]]; then
    log "Web directory is missing: $NEW_RELEASE/web"
    exit 1
fi

if [[ ! -f "$NEW_RELEASE/web/index.html" ]]; then
    log "Web entry file is missing: $NEW_RELEASE/web/index.html"
    exit 1
fi

find "$NEW_RELEASE/web" -type d -exec chmod 0755 {} +
find "$NEW_RELEASE/web" -type f -exec chmod 0644 {} +

if ! runuser -u www-data -- test -r "$NEW_RELEASE/web/index.html"; then
    log "Nginx user www-data cannot read web/index.html."
    namei -l "$NEW_RELEASE/web/index.html" || true
    exit 1
fi

log "Verified that Nginx can read: $NEW_RELEASE/web/index.html"
log "Prepared release: $NEW_RELEASE"

# ======================== Atomic activation ========================
NEXT_LINK="$BASE/.current-next-$$"
rm -f -- "$NEXT_LINK"
ln -s -- "$NEW_RELEASE" "$NEXT_LINK"
mv -Tf -- "$NEXT_LINK" "$CURRENT"
ACTIVATED=1

ACTIVATED_RELEASE="$(readlink -f "$CURRENT")"
EXPECTED_RELEASE="$(readlink -f "$NEW_RELEASE")"

if [[ "$ACTIVATED_RELEASE" != "$EXPECTED_RELEASE" ]]; then
    log "current link verification failed."
    log "Expected: $EXPECTED_RELEASE"
    log "Actual:   $ACTIVATED_RELEASE"
    exit 1
fi

log "Activated current -> $ACTIVATED_RELEASE"

# ======================== Restart and verify ========================
systemctl daemon-reload
systemctl restart "$SERVICE"

health_ok=0
for (( attempt=1; attempt<=HEALTH_RETRIES; attempt++ )); do
    if systemctl is-active --quiet "$SERVICE"; then
        PID="$(systemctl show "$SERVICE" -p MainPID --value)"
        if [[ "$PID" =~ ^[1-9][0-9]*$ && -d "/proc/$PID" ]]; then
            RUNNING_RELEASE="$(readlink -f "/proc/$PID/cwd" 2>/dev/null || true)"

            if [[ "$RUNNING_RELEASE" == "$EXPECTED_RELEASE" ]]; then
                HTTP_CODE="$(curl -sS --max-time 5 \
                    -o /dev/null \
                    -w '%{http_code}' \
                    -H "Host: $SITE_HOST" \
                    -H 'Cache-Control: no-cache' \
                    "$HEALTH_URL" 2>/dev/null || true)"

                # The process and working directory were already verified above.
                # Any HTTP response below 500 proves that the new application is
                # accepting requests. This deliberately accepts 401/403/404,
                # because an API root may not expose a public GET health route.
                if [[ "$HTTP_CODE" =~ ^[1-4][0-9]{2}$ ]]; then
                    log "Health check responded with HTTP $HTTP_CODE."
                    health_ok=1
                    break
                fi

                log "Health endpoint returned HTTP ${HTTP_CODE:-000}."
            fi
        fi
    fi

    log "Health check $attempt/$HEALTH_RETRIES not ready yet."
    sleep "$HEALTH_INTERVAL"
done

if (( ! health_ok )); then
    log "Service verification failed."
    log "systemd status:"
    systemctl status "$SERVICE" --no-pager -l || true
    log "Recent service logs:"
    journalctl -u "$SERVICE" --since "10 minutes ago" --no-pager -n 200 || true
    exit 1
fi

# Re-read final values after successful check.
ACTIVATED_RELEASE="$(readlink -f "$CURRENT")"
PID="$(systemctl show "$SERVICE" -p MainPID --value)"
RUNNING_RELEASE="$(readlink -f "/proc/$PID/cwd")"

if [[ "$ACTIVATED_RELEASE" != "$EXPECTED_RELEASE" ]]; then
    log "current changed unexpectedly after service start."
    exit 1
fi

if [[ "$RUNNING_RELEASE" != "$EXPECTED_RELEASE" ]]; then
    log "Service is not running from the activated release."
    log "Expected: $EXPECTED_RELEASE"
    log "Running:  $RUNNING_RELEASE"
    exit 1
fi

write_report "SUCCESS"

# ======================== Retention ========================
if [[ "$KEEP_RELEASES" =~ ^[0-9]+$ ]] && (( KEEP_RELEASES > 0 )); then
    mapfile -t OLD_RELEASES < <(
        find "$RELEASES" -mindepth 1 -maxdepth 1 -type d ! -name '.staging-*' \
            -printf '%T@ %p\n' | sort -nr | tail -n "+$((KEEP_RELEASES + 1))" | cut -d' ' -f2-
    )

    for release in "${OLD_RELEASES[@]:-}"; do
        [[ -n "$release" ]] || continue
        [[ "$(readlink -f "$release")" == "$ACTIVATED_RELEASE" ]] && continue
        [[ -n "$OLD_RELEASE" && "$(readlink -f "$release")" == "$OLD_RELEASE" ]] && continue
        log "Removing old release: $release"
        rm -rf --one-file-system -- "$release"
    done
fi

ACTIVATED=0

log "Deployment successful."
log "Package: $PACKAGE"
log "Current: $ACTIVATED_RELEASE"
log "Running: $RUNNING_RELEASE"
log "Report:  $REPORT_FILE"
log "Log:     $LOG_FILE"
