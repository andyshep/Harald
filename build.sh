#!/bin/bash

PLATFORMS=macOS

carthage update --no-use-binaries --platform ${PLATFORMS}
