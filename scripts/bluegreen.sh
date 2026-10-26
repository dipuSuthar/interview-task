#!/usr/bin/env bash
# Blue/green deployment driver (run from CI after `terraform init`).
#   ACTION=deploy   APP_VERSION=<git sha>  -> build new colour, verify, switch traffic, retire old
#   ACTION=rollback                        -> bring the previous colour back and switch to it
#   ACTION=destroy                         -> tear everything down
# Env: TF_DIR (default terraform/environments/dev), KEEP_STANDBY=true to keep the old fleet running.
set -euo pipefail

ACTION="${ACTION:-deploy}"
TF_DIR="${TF_DIR:-terraform/environments/dev}"
APP_VERSION="${APP_VERSION:-}"
KEEP_STANDBY="${KEEP_STANDBY:-false}"
cd "$TF_DIR"

out()   { terraform output -raw "$1" 2>/dev/null || true; }
other() { [ "$1" = "blue" ] && echo green || echo blue; }

# apply <active> <blue_enabled> <green_enabled> <blue_version> <green_version>
apply() {
  terraform apply -auto-approve -input=false \
    -var "active_color=$1" -var "blue_enabled=$2" -var "green_enabled=$3" \
    -var "blue_version=$4" -var "green_version=$5"
}

healthy_targets() { # <color>
  local arn
  arn=$(terraform output -json target_group_arns | jq -r ".$1")
  aws elbv2 describe-target-health --target-group-arn "$arn" \
    --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" --output text
}

wait_healthy() { # <color> <min>
  for i in $(seq 1 40); do
    n=$(healthy_targets "$1")
    echo "[$1] healthy targets: $n (need >= $2)"
    [ "$n" -ge "$2" ] && return 0
    sleep 15
  done
  return 1
}

smoke_test() { # <expected_color> <expected_version>
  local url body
  url="$(out app_url)"
  echo "Smoke testing $url/api/status (expect colour=$1 version=$2)"
  # Retries cover DNS propagation and the first request after cut-over.
  for i in $(seq 1 30); do
    if body=$(curl -fsS --max-time 10 "$url/api/status" 2>/dev/null) \
       && [ "$(echo "$body" | jq -r .status)" = "ok" ] \
       && [ "$(echo "$body" | jq -r .color)" = "$1" ] \
       && [ "$(echo "$body" | jq -r .version)" = "$2" ]; then
      echo "$body" | jq .
      curl -fsS --max-time 10 -o /dev/null -w "HTTP %{http_code} on /health\n" "$url/health"
      curl -fsS --max-time 10 -X POST "$url/api/storage/check" | jq .
      return 0
    fi
    sleep 10
  done
  return 1
}

versions() { # sets BLUE_V GREEN_V from state
  BLUE_V="$(out blue_version)"; GREEN_V="$(out green_version)"
}

cut_over() { # <new_active> <old_active> <blue_v> <green_v> <expected_version>
  local new="$1" old="$2" bv="$3" gv="$4" ver="$5"
  local be=true ge=true
  echo "== Switching traffic: $old -> $new =="
  apply "$new" "$be" "$ge" "$bv" "$gv"
  if ! smoke_test "$new" "$ver"; then
    echo "!! Smoke test failed - rolling traffic back to $old"
    apply "$old" "$be" "$ge" "$bv" "$gv"
    exit 1
  fi
  if [ "$KEEP_STANDBY" = "true" ]; then
    echo "Keeping $old fleet as warm standby (rollback = instant)."
  else
    echo "== Retiring $old fleet =="
    [ "$old" = "blue" ] && be=false || ge=false
    apply "$new" "$be" "$ge" "$bv" "$gv"
  fi
}

case "$ACTION" in
  deploy)
    [ -n "$APP_VERSION" ] || { echo "APP_VERSION required"; exit 2; }
    ACTIVE="$(out active_color)"
    if [ -z "$ACTIVE" ]; then
      echo "== First deployment: creating infrastructure with blue active =="
      apply blue true false "$APP_VERSION" "$APP_VERSION"
      smoke_test blue "$APP_VERSION"
      exit 0
    fi
    IDLE="$(other "$ACTIVE")"; versions
    [ "$IDLE" = "blue" ] && BLUE_V="$APP_VERSION" || GREEN_V="$APP_VERSION"
    echo "== Active: $ACTIVE | deploying $APP_VERSION to idle: $IDLE =="
    apply "$ACTIVE" true true "$BLUE_V" "$GREEN_V"   # builds idle fleet, no traffic yet
    wait_healthy "$IDLE" 1
    cut_over "$IDLE" "$ACTIVE" "$BLUE_V" "$GREEN_V" "$APP_VERSION"
    ;;
  rollback)
    ACTIVE="$(out active_color)"; [ -n "$ACTIVE" ] || { echo "Nothing deployed"; exit 2; }
    IDLE="$(other "$ACTIVE")"; versions
    IDLE_V=$([ "$IDLE" = "blue" ] && echo "$BLUE_V" || echo "$GREEN_V")
    echo "== Rolling back: $ACTIVE -> $IDLE (version $IDLE_V) =="
    apply "$ACTIVE" true true "$BLUE_V" "$GREEN_V"
    wait_healthy "$IDLE" 1
    cut_over "$IDLE" "$ACTIVE" "$BLUE_V" "$GREEN_V" "$IDLE_V"
    ;;
  destroy)
    terraform destroy -auto-approve -input=false
    ;;
  *) echo "Unknown ACTION=$ACTION"; exit 2 ;;
esac
