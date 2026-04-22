LOCAL targetModules IS SHIP:MODULESNAMED("USI_Harvester").
for harvester in targetModules {
	for eventName in harvester:ALLEVENTNAMES {
		if eventName:startswith("start") {
			harvester:DOEVENT(eventName).
		}
	}
}
