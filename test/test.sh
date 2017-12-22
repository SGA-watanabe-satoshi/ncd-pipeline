#!/bin/bash

set -eo pipefail

exec $HOME/bats/bin/bats test.bats
