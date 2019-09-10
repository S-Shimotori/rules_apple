#!/bin/bash

# Copyright 2019 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eu

newline=$'\n'

# This script allows many of the functions in apple_shell_testutils.sh to be
# called through apple_verification_test_runner.sh.template by using environment
# variables.
#
# Supported operations:
#  CONTAINS: takes a list of files to test for existance. The filename will be
#      expanded with bash and can contain variables (e.g. $BUNDLE_ROOT)
#  NOT_CONTAINS: takes a list of files to test for non-existance. The filename
#      will be expanded with bash and can contain variables (e.g. $BUNDLE_ROOT)
#  IS_BINARY_PLIST: takes a list of paths to plist files and checks that they
#      are `binary` format. Filenames are expanded with bash.
#  IS_NOT_BINARY_PLIST: takes a list of paths to plist files and checks that
#      they are not `binary` format. Filenames are expanded with bash.
#  PLIST_TEST_FILE: The plist file to test with `PLIST_TEST_VALUES`.
#  PLIST_TEST_VALUES: Array for keys and values in the format "KEY VALUE" where
#      the key is in PlistBuddy format(which can't contain spaces), followed by
#      by a single space, followed by the value to test. * can be used as a
#      wildcard value.

# Test that the archive contains the specified files in the CONTAIN env var.
if [[ -n "${CONTAINS-}" ]]; then
  for path in "${CONTAINS[@]}"
  do
    expanded_path=$(eval echo "$path")
    if [[ ! -e $expanded_path ]]; then
      fail "Archive did not contain \"$expanded_path\"" \
        "contents were:$newline$(find $ARCHIVE_ROOT)"
    fi
  done
fi

# Test that the archive doesn't contains the specified files in NOT_CONTAINS.
if [[ -n "${NOT_CONTAINS-}" ]]; then
  for path in "${NOT_CONTAINS[@]}"
  do
    expanded_path=$(eval echo "$path")
    if [[ -e $expanded_path ]]; then
      fail "Archive did contain \"$expanded_path\""
    fi
  done
fi

# Test that plist files are in a binary format.
if [[ -n "${IS_BINARY_PLIST-}" ]]; then
  for path in "${IS_BINARY_PLIST[@]}"
  do
    expanded_path=$(eval echo "$path")
    if [[ ! -e $expanded_path ]]; then
      fail "Archive did not contain plist \"$expanded_path\"" \
        "contents were:$newline$(find $ARCHIVE_ROOT)"
    fi
    if ! grep -sq "^bplist00" $expanded_path; then
      fail "Plist does not have binary format \"$expanded_path\""
    fi
  done
fi

# Test that plist files are not in a binary format.
if [[ -n "${IS_NOT_BINARY_PLIST-}" ]]; then
  for path in "${IS_NOT_BINARY_PLIST[@]}"
  do
    expanded_path=$(eval echo "$path")
    if [[ ! -e $expanded_path ]]; then
      fail "Archive did not contain plist \"$expanded_path\"" \
        "contents were:$newline$(find $ARCHIVE_ROOT)"
    fi
    if grep -sq "^bplist00" $expanded_path; then
      fail "Plist has binary format \"$expanded_path\""
    fi
  done
fi


# Use `PlistBuddy` to test for key/value pairs in a plist/string/car file.
if [[ -n "${PLIST_TEST_VALUES-}" ]]; then
  if [[ ${#PLIST_TEST_FILE[@]} -eq 0 ]]; then
    fail "Plist test values passed, but no plist file specified."
  fi
  path=$(eval echo "$PLIST_TEST_FILE")
  if [[ ! -e $path ]]; then
    fail "Archive did not contain plist at \"$path\"" \
      "contents were:$newline$(find $ARCHIVE_ROOT)"
  fi
  for test_values in "${PLIST_TEST_VALUES[@]}"
  do
    # Keys and expected-values are in the format "KEY VALUE".
    IFS=' ' read -r key expected_value <<< "$test_values"
    value="$(/usr/libexec/PlistBuddy -c "Print $key" $path 2>/dev/null || true)"
    if [[ -z "$value" ]]; then
      fail "Expected \"$key\" to be in plist \"$path\". Plist contents:" \
        "$newline$(/usr/libexec/PlistBuddy -c Print $path)"
    fi
    if [[ "$value" != $expected_value ]]; then
      fail "Expected plist value \"$value\" to be \"$expected_value\""
    fi
  done
fi
