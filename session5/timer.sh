#!/bin/bash

run_with_timer() {
  local total_steps=$1
  local delay_seconds=$2
  local SECONDS=0

  for ((i = 1; i <= total_steps; i++)); do
    printf "\r⏱️ Elapsed: %02d:%02d" $((SECONDS / 60)) $((SECONDS % 60))
    sleep "$delay_seconds"
    ((SECONDS += delay_seconds))
  done

  echo -e "\n✅ Done. Duration: $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)"
}
