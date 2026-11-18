#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  export GITHUB_REPO=trebormc/ddev-claude-code

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

health_checks() {
  run ddev add-on list --installed
  assert_success
  assert_output --partial "ddev-claude-code"
  # The usage wrapper must front the native launcher on PATH after the
  # self-update, in plain exec and in login shells alike
  run ddev exec -s claude-code bash -c 'command -v claude'
  assert_success
  assert_output "/opt/ddev-ai/bin/claude"
  run ddev exec -s claude-code bash -lc 'command -v claude'
  assert_success
  assert_output "/opt/ddev-ai/bin/claude"
  run ddev exec -s claude-code head -c 512 /opt/ddev-ai/bin/claude
  assert_success
  assert_output --partial "ddev-generated"
  run ddev exec -s claude-code claude --version
  assert_success
  assert_output --partial "Claude Code"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

# bats test_tags=command
@test "command and argument handling" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  # Check the version of Claude.
  run ddev claude-code --version
  assert_success
  assert_output --partial "(Claude Code)"
  # The shortcut and the raw claude command take the same options.
  run ddev cc --version
  assert_success
  assert_output --partial "(Claude Code)"
  run ddev claude --version
  assert_success
  assert_output --partial "(Claude Code)"
  # Captured output must not carry the tab title escape sequences.
  refute_output --partial $'\033]0;'
  # Normal commands being passed in should work as expected.
  run ddev claude-code test -f /.dockerenv
  assert_success
  run ddev claude-code test -d /.dockerenv
  assert_failure
}
