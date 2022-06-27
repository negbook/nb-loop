This is a release specifically for developers, which should help when using loops.
# nb-loop
fxmanifest.lua

```
shared_scripts {
  "@nb-loop/nb-loop.lua"
}

dependencies {
	'nb-loop',
  ...
}
```

# techs
single method, for i=1,#n do as optimized as possible. which just like using
```
CreateThread(function() while true do Wait(duration) end end)
``` 
but with more managements.

## functions
```
local handle = PepareLoop(duration)
handle:delete()
handle:set(duration)
handle:get()
handle:add(fn,callbackondelete)
handle(...)   = handle:add

local handle = PepareLoop(1000)
local attempt = 0
handle(function(duration)
    print(duration("get")) 
    attempt  = attempt  + 1
    duration("set",math.random(0,500)) -- set this duration into random 0 - 500
    if attempt >= 10 then 
       duration("kill") --kill this task, also you can handle:delete()
       print('killed')
    end 
end)
```

## shit examples
```
local Loop = PepareLoop(1000) --create a handle Loop
local Loop2 = PepareLoop(1000) --create a handle Loop2

Loop(function(duration)
    print("Loop test "..duration("get"))
    print(Loop) -- print what duration it is ,and total threads we created by nb-loop
end)

Loop2(function(duration)
    print("Loop2 test "..duration("get"))
    duration("set",5000) --set a loop task to new duration, it will create a new thread or join existed duration thread

end )


local Loop3 = PepareLoop(0,function(obj)
    print('some of loop3 is released',obj("getfn"))
end) -- we can set callback when some task just killed

Loop3(function(duration)
    print("Loop test2 "..duration("get"))
    duration("set",math.random(0,500))
end,function()
    print('Loop3 is released released released')
end) --insert a task and print something, it would change random duration during running
Loop3:delete(3000) --delete above task after 3 seconds

Loop3(function(duration)
    print("Loop test22 "..duration("get"))
    duration("kill")
end,function()
    print('Loop32 is released released released')
end) -- insert a task into the handle : Loop3(PepareLoop)

```

# better example
without nb-loop:(lets say [LegacyFuel](https://github.com/InZidiuZ/LegacyFuel/blob/master/source/fuel_client.lua) line:77)
```
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(250)

		local pumpObject, pumpDistance = FindNearestFuelPump()

		if pumpDistance < 2.5 then
			isNearPump = pumpObject

			if Config.UseESX then
				local playerData = ESX.GetPlayerData()
				for i=1, #playerData.accounts, 1 do
					if playerData.accounts[i].name == 'money' then
						currentCash = playerData.accounts[i].money
						break
					end
				end
			end
		else
			isNearPump = false

			Citizen.Wait(math.ceil(pumpDistance * 20))
		end
	end
end)
```

with nb-loop we can:
```
local Loop = PepareLoop(1000)
Loop(function(durationRef)
        local foundingCoords = GetEntityCoords(PlayerPedId())
        if not IsAnyObjectNearPoint(foundingCoords.x,foundingCoords.y,foundingCoords.z,2.5,false) then return nil end  
	local pumpObject, pumpDistance = FindNearestFuelPump()
	if pumpDistance < 2.5 then
		isNearPump = pumpObject

		if Config.UseESX then
			local playerData = ESX.GetPlayerData()
			for i=1, #playerData.accounts, 1 do
				if playerData.accounts[i].name == 'money' then
					currentCash = playerData.accounts[i].money
					break
				end
			end
		end
	else
		isNearPump = false
        local duration = math.ceil(pumpDistance * 20)
        duration = duration >= 2500 and 2500 or duration 
        durationRef("set",duration)
	end
end 
```

we can also : 
```

local Loop1

local Loop2 = PepareLoop(5000)
    
Loop2(function()
    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed) then return nil end
    
    local fuelModels = {
        `somesomesome`
    }
    local foundingCoords = PlayerFrontVecotr(0.0,0.5,0.0)
    if not IsAnyObjectNearPoint(foundingCoords.x,foundingCoords.y,foundingCoords.z,10.0,false) then return nil end  
    local found = false 
    for i,hash in pairs(atmModels) do 
        if DoesObjectOfTypeExistAtCoords(foundingCoords.x, foundingCoords.y, foundingCoords.z, 10.0, hash, false) then 
            found = hash 
            break 
        end
    end 
    if found then 
        if not Loop1 then 
            Loop1 = PepareLoop(2500)
            Loop1(function(durationRef)
                local pumpObject, pumpDistance = FindNearestFuelPump()
                if pumpDistance < 2.5 then
                    isNearPump = pumpObject

                    if Config.UseESX then
                        local playerData = ESX.GetPlayerData()
                        for i=1, #playerData.accounts, 1 do
                            if playerData.accounts[i].name == 'money' then
                                currentCash = playerData.accounts[i].money
                                break
                            end
                        end
                    end
                else
                    isNearPump = false
                    local duration = math.ceil(pumpDistance * 20)
                    duration = duration >= 2500 and 2500 or duration 
                    durationRef("set",duration)
                end
            end,function()
                Loop1 = nil
            end)
        end 
    elseif Loop1 then  
        Loop1:delete()
    end 
end) 
```
