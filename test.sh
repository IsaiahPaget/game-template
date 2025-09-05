#!/usr/bin/env bash
set -eu

odin test tests -define:ODIN_TEST_THREADS=1 -define:TESTING=true
