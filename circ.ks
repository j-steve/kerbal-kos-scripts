run common.ks.

local currentRadius is ship:altitude + body:radius. // Assuming at current altitude
local txfrDeltaV is calcVisViva(currentRadius, ship:orbit:semimajoraxis, currentRadius, ship:orbit:semimajoraxis).