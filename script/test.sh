#!/bin/bash

set -euxo pipefail

TOP_DIR="$(dirname "${0}")/.."

function clear_tmp {
    rm -rf "${TMP_DIR}"
    mkdir "${TMP_DIR}"
}

PCH_CHECK="true"

# Show the environment
rpm -q gcc
rpm -q redhat-rpm-config
# PATH="/home/root/local/ruby-2.7.1-jit-disable-making-pch/bin:$PATH"
PATH="/home/root/local/ruby-2.7.1-clang/bin:$PATH"
command -v ruby
rpm -qf "$(command -v ruby)" || true
ruby -v
gem -v

# Install dependencies
# An iterations per second (i/s) enhancement to Benchmark.
# https://github.com/evanphx/benchmark-ips
# Installation fails with the latest version 2.8.0.
# https://github.com/evanphx/benchmark-ips/issues/100
gem install benchmark-ips --user-install -v 2.7.2

TMP_DIR="$(pwd)/tmp"

# ==================
# 1: Basic tests
echo "=== Basic tests ==="

ruby --jit --disable-gems -e 'puts "Hello"'
ruby --jit -e 'puts "Hello"'
ruby --jit --jit-verbose=2 -e 'puts "Hello"'

clear_tmp
TMP="${TMP_DIR}" ruby --jit --jit-verbose=2 --jit-save-temps -e 'puts "Hello"'
ls -1 "${TMP_DIR}"
if [ "${PCH_CHECK}" = "true" ]; then
  ls "${TMP_DIR}" | grep -q '^_ruby_mjit_.*\.gch$'
fi

clear_tmp
TMP="${TMP_DIR}" ruby --disable-gems --jit --jit-verbose=2 --jit-save-temps --jit-min-calls=1 --jit-wait -e '1.times { puts "Hello" }'
ls -1 "${TMP_DIR}"
if [ "${PCH_CHECK}" = "true" ]; then
  ls "${TMP_DIR}" | grep -q '^_ruby_mjit_.*\.gch$'
  ls "${TMP_DIR}" | grep -q '^_ruby_mjit_.*\.so$'
fi

# ==================
# 2: Benchmark tests
echo "=== Benchmark tests ==="

ruby "${TOP_DIR}/script/bench.rb"
ruby --jit "${TOP_DIR}/script/bench.rb"
# On Ruby 2.7, the default values of
# --jit-min-calls is changed from 5 to 10000.
# --jit-max-cache is changed from 1000 to 100.
# This test is to do benchmark by Ruby 2.6's default values.
# https://github.com/ruby/ruby/commit/0fa4a6a618295d42eb039c65f0609fdb71255355
ruby --jit --jit-min-calls=5 --jit-max-cache=1000 "${TOP_DIR}/script/bench.rb"

clear_tmp
TMP="${TMP_DIR}" ruby --jit --jit-verbose=2 --jit-save-temps --jit-min-calls=5 --jit-max-cache=1000 "${TOP_DIR}/script/bench.rb"
ls -1 "${TMP_DIR}"
if [ "${PCH_CHECK}" = "true" ]; then
  ls "${TMP_DIR}" | grep -q '^_ruby_mjit_.*\.gch$'
  ls "${TMP_DIR}" | grep -q '^_ruby_mjit_.*\.so$'
fi

exit 0
