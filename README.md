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
    duration("set",5000)

end )


local Loop3 = PepareLoop(0,function(obj)
    print('some of loop3 is released',obj("getfn"))
end)
Loop3(function(duration)
    print("Loop test2 "..duration("get"))
    duration("set",math.random(0,500))
end,function()
    print('Loop3 is released released released')
end)
Loop3:delete(3000)
Loop3(function(duration)
    print("Loop test22 "..duration("get"))
    duration("kill")
end,function()
    print('Loop32 is released released released')
end)

```
