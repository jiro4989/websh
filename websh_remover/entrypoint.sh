#!/bin/sh

set -eu

nimble build -Y
./bin/websh_remover
