#!/usr/bin/env bash
# Offline regression using native JSON layouts and Git/Docker/Bazel stubs.
set -euo pipefail
release_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/release.sh"
manifest_script="${release_script%/*}/image_manifest.py"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
cd "$test_root"
ln -s "$manifest_script" image_manifest.py

operation() { printf '%s\n' "$*" >> "$test_log"; }
git() {
  operation "git $*"
  case "$*" in
    'status --porcelain --untracked-files=all')
      [[ "$test_failure" != git-status ]] || return 42
      case "$test_failure" in dirty-tracked) echo ' M source.py';; dirty-untracked) echo '?? source.py';; esac ;;
    'rev-parse --verify HEAD') echo "$test_commit" ;;
    'show -s --format=%ct HEAD') echo 1790875499 ;;
    *) return 98 ;;
  esac
}
bazel() {
  operation "bazel $*"
  case "$*" in
    "build //:pyva_runtime_${test_minor//./_}") ;;
    "run //:pyva_runtime_${test_minor//./_}_push -- --repository $test_repository --tag $test_tag") ;;
    *) echo "Unexpected Bazel command: $*" >&2; return 98 ;;
  esac
}
bash() {
  operation "bash $*"
  [[ "$1" == smoke_test.sh && "$2" == "$test_minor" && "$3" == --arch ]] || return 98
  local arch="$4" phase=base
  if (( $# == 5 )); then
    phase=remote
    [[ "$5" == "$test_repository@$test_index" && "$(cat "$test_root/pulled")" == "$arch" ]] || return 98
  else [[ $# == 4 ]] || return 98; fi
  [[ "$test_failure" != "$phase-$arch" ]] || return 42
}
docker() {
  operation "docker $*"
  case "$*" in
    'image inspect --platform linux/'*)
      local image="${@: -1}" arch="${4#linux/}" fault=none
      [[ "$5" == --format && "$6" == '{{json .}}' && ( "$arch" == amd64 || "$arch" == arm64 ) ]] || return 98
      if [[ "$image" == "$test_repository@$test_index" ]]; then [[ "$(cat "$test_root/pulled")" == "$arch" ]] || return 98;
      else [[ "${image##*-}" == "$arch" ]] || return 98; fi
      if [[ "$test_failure" == load-digest && "$image" == pyva-runtime:* || "$test_failure" == pull-digest && "$image" == "$test_repository@$test_index" ]]; then fault=layers; fi
      command python3 - "$test_root/loaded-$arch.json" "$fault" <<'PYJSON'
import json, sys
m=json.load(open(sys.argv[1]))
if sys.argv[2]=='layers': m['RootFS']['Layers']=['sha256:'+'0'*64]
print(json.dumps(m))
PYJSON
      ;;
    'build --platform linux/'*) ;;
    'run --rm --platform linux/'*)
      local arch="${4#linux/}"
      [[ "$test_failure" != "poi-$arch" ]] || return 42 ;;
    "pull --platform linux/amd64 $test_repository@$test_index"|"pull --platform linux/arm64 $test_repository@$test_index")
      [[ "$test_failure" != pull ]] || return 42
      echo "${3#linux/}" > "$test_root/pulled" ;;
    'buildx imagetools inspect '*)
      local count=0
      [[ ! -f "$test_root/inspects" ]] || count="$(cat "$test_root/inspects")"
      count=$((count+1))
      echo "$count" > "$test_root/inspects"
      if (( count == 1 )); then
        case "$test_failure" in
          auth) echo 'ERROR: unauthorized' >&2; return 1 ;;
          transport) echo 'ERROR: dial tcp timeout' >&2; return 1 ;;
          unknown) echo 'ERROR: registry unexpected response' >&2; return 1 ;;
          ambiguous-absence) echo "ERROR: $4: not found (proxy response)" >&2; return 1 ;;
        esac
        if [[ "$test_existing" == false && "$test_failure" != collision ]]; then
          echo "ERROR: $4: not found" >&2; return 1
        fi
      fi
      local fault=none
      if [[ "$test_failure" == collision && "$count" == 1 || "$test_failure" == remote-index && "$count" == 2 || "$test_failure" == channel-digest && "$count" == 3 ]]; then fault=index; fi
      if [[ "$test_failure" == remote-child && "$count" == 2 ]]; then fault=child; fi
      if [[ "$test_failure" == remote-platform && "$count" == 2 ]]; then fault=platform; fi
      command python3 - "$test_root/remote.json" "$fault" <<'PY'
import json, sys
m=json.load(open(sys.argv[1]))
if sys.argv[2]=='index': m['digest']='sha256:'+'0'*64
if sys.argv[2]=='child': m['manifests'][1]['digest']='sha256:'+'0'*64
if sys.argv[2]=='platform': m['manifests'][1]['platform']['architecture']='amd64'
print(json.dumps(m))
PY
      ;;
    "buildx imagetools create --tag $test_repository:${test_minor}-java21-debian13 $test_repository@$test_index")
      [[ "$test_failure" != channel-copy ]] || return 42
      command grep -q "bash smoke_test.sh $test_minor --arch arm64 $test_repository@$test_index" "$test_log" || return 98 ;;
    *) echo "Unexpected Docker command: $*" >&2; return 98 ;;
  esac
}
export -f operation git bazel bash docker
export test_root test_log test_minor test_repository test_commit test_tag test_index test_amd64_config test_arm64_config test_existing test_failure

test_repository=index.docker.io/example/pyva-runtime
test_commit=c9019d10b9bde89ed69d4e9e30a551e8951cb6d7
test_existing=false
test_failure=none
prepare() {
  test_tag="${test_minor}.99-java21-debian13-20261001T172459Z-g${test_commit}"
  test_log="$test_root/operations"
  : > "$test_log"
  rm -f "$test_root/inspects" "$test_root/pulled"
  command python3 - "$test_root" "$test_minor" <<'PY'
import hashlib, json, pathlib, sys
root=pathlib.Path(sys.argv[1]); minor=sys.argv[2]
layout=root/'bazel-bin'/('pyva_runtime_'+minor.replace('.','_'))
blobs=layout/'blobs/sha256'; blobs.mkdir(parents=True,exist_ok=True)
def save(data):
    raw=json.dumps(data).encode(); sha=hashlib.sha256(raw).hexdigest()
    (blobs/sha).write_bytes(raw)
    return {'digest':'sha256:'+sha,'size':len(raw)}
children=[]; configs={}
for arch in ('amd64','arm64'):
    config={'os':'linux','architecture':arch,'config':{'Labels':{'org.opencontainers.image.version':minor+'.99-java21-debian13'}},'rootfs':{'diff_ids':[]}}
    cfg=save(config)
    (root/('loaded-'+arch+'.json')).write_text(json.dumps({'Os':'linux','Architecture':arch,'Config':config['config'],'RootFS':{'Layers':[]}}))
    configs[arch]=cfg['digest']
    child=save({'config':cfg,'layers':[]}); child['platform']={'os':'linux','architecture':arch}
    children.append(child)
idx={'manifests':children}; desc=save(idx)
(layout/'index.json').write_text(json.dumps({'manifests':[desc]}))
(root/'remote.json').write_text(json.dumps(dict(idx,digest=desc['digest'])))
(root/'variables').write_text('\n'.join(f'test_{k}={v}' for k,v in {'index':desc['digest'],**{a+'_config':v for a,v in configs.items()}}.items()))
PY
  source "$test_root/variables"
}
run_case() {
  prepare
  local status=0
  output="$(command bash "$release_script" "$@" 2>&1)" || status=$?
  if [[ "$test_failure" == none ]]; then
    [[ "$status" == 0 && "$output" == *"Published $test_repository:$test_tag ($test_repository@$test_index)"* ]] || { echo "$output" >&2; return 1; }
    if [[ "$test_existing" == true ]]; then ! command grep -q '^bazel run' "$test_log"; else command grep -q '^bazel run' "$test_log"; fi
    for arch in amd64 arm64; do
      command grep -q "bash smoke_test.sh $test_minor --arch $arch $test_repository@$test_index" "$test_log"
    done
    if [[ "${1:-}" == --channel ]]; then command grep -q 'imagetools create' "$test_log"; else ! command grep -q 'imagetools create' "$test_log"; fi
  else
    [[ "$status" != 0 && "$output" != *'Published '* ]] || { echo "Failure escaped: $test_failure" >&2; return 1; }
    case "$test_failure" in
      git-status|dirty-*|base-*|poi-*|load-digest|collision|auth|transport|unknown|ambiguous-absence) ! command grep -q '^bazel run' "$test_log" ;;
    esac
    if [[ "$test_failure" != channel-* ]]; then ! command grep -q 'imagetools create' "$test_log"; fi
  fi
}
for test_minor in 3.13 3.14; do
  for test_existing in false true; do
    run_case "$test_minor" docker.io/example/pyva-runtime
    normal_output="$output"
    TZ=Pacific/Honolulu SOURCE_DATE_EPOCH=0 run_case "$test_minor" index.docker.io/example/pyva-runtime
    [[ "$normal_output" == "$output" ]]
    run_case --channel "$test_minor" docker.io/example/pyva-runtime
  done
  test_existing=false
  for test_failure in git-status dirty-tracked dirty-untracked base-amd64 base-arm64 poi-amd64 poi-arm64 \
    load-digest collision auth transport unknown ambiguous-absence remote-index remote-child remote-platform \
    pull pull-digest remote-amd64 remote-arm64 channel-copy channel-digest; do
    run_case --channel "$test_minor" docker.io/example/pyva-runtime
  done
  test_failure=none
  previous_commit="$test_commit"
  test_commit=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  run_case "$test_minor" docker.io/example/pyva-runtime
  [[ "$output" == *"-g${test_commit}"* && "$output" != *"-g${previous_commit}"* ]]
  test_commit="$previous_commit"
done

reject() {
  : > "$test_log"
  local status=0 output
  output="$(command bash "$release_script" "$@" 2>&1)" || status=$?
  [[ "$status" == 2 && "$output" == *usage:* && ! -s "$test_log" ]] || return 1
}
reject
reject 3.13
reject --channel 3.13
reject 3.12 index.docker.io/example/runtime
reject 3.13 index.docker.io/example/runtime extra
for destination in '' example/runtime ghcr.io/example/runtime docker.io.evil/example/runtime \
  https://docker.io/example/runtime docker.io:443/example/runtime; do reject 3.13 "$destination"; done
for host in docker.io index.docker.io; do
  for repo_path in example /runtime example/ example/runtime/ example//runtime example/runtime/extra \
    Example/runtime example/Runtime example/runtime:tag example/runtime@sha256:abcd \
    'exam ple/runtime' 'example/run time' 'example/runtime ' $'example/runtime\n' $'example/run\ttime' \
    -example/runtime example-/runtime example/.runtime example/runtime. \
    example/runtime..name example/runtime___name example/runtime_-name example/runtime+name; do
    reject 3.13 "${host}/${repo_path}"
    reject --channel 3.14 "${host}/${repo_path}"
  done
done
# Valid separator forms still work.
for test_repository in index.docker.io/a0.b_1__c--2/r0.s_1__t---2; do
  run_case 3.14 "$test_repository"
done

echo 'Release regression passed: deterministic identity, immutable protection, both-platform gates and verified channel copy'
