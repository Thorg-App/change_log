#!/usr/bin/env bash
# __enable_bash_strict_mode__

main() {
  cdi "$(caller_dir)"

  templatize_mustache_v2 _README.template.md > README.md
}

main "${@}"
