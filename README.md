# nb-loop
fxmanifest.lua

```
shared_scripts {
  @nb-loop/nb-loop.lua
}

dependencies {
	'nb-loop',
  ...
}
```

## examples
```
local Loop = PepareLoop(1000)
local Loop2 = PepareLoop(1000)

Loop(function(duration)
    print("Loop test "..duration("get"))
    print(Loop)
end)

Loop2(function(duration)
    print("Loop2 test "..duration("get"))
    duration("set",500)

end )

Loop2:delete()

local Loop = PepareLoop(1000)
Loop(function(duration)
    duration("set",math.random(0,500))
end)

Loop:delete(3000)
```
