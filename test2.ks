
clearscreen.

print sumDeltaV().


function sumDeltaV {
  parameter startStage is STAGE:NUMBER. // Default to current stage if no argument is passed

  local totalDeltaV is 0. // Initialize total delta-v counter

  // Iterate over all stages from the current stage down to stage 0
  for stage from startStage to 0 step -1 {
    if stage:DELTAV > 0 {
      set totalDeltaV to totalDeltaV + stage:DELTAV.
    }
  }

  return totalDeltaV.
}