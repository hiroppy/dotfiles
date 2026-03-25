#!/bin/sh
cd "$1" && git rev-parse --abbrev-ref HEAD 2>/dev/null
