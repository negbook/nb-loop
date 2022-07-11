local _M_ = {}
do 

    local totalThread = 0
    local debugMode = false
    local e = {} setmetatable(e,{__call = function(t,...) end})
    local newLoopThread = function(t,k)  
        CreateThread(function()
            totalThread = totalThread + 1
            local o = t[k]
            repeat 
                local tasks = (o or e)
                local n = #tasks
                if n==0 then 
                    goto end_loop 
                end 
                for i=1,n do 
                    (tasks[i] or e)()
                end 
            until n == 0 or Wait(k) 
            ::end_loop::
            totalThread = totalThread - 1
            t[k] = nil

            return 
        end)
    end   

    local Loops = setmetatable({[e]=e}, {__newindex = function(t, k, v)
        rawset(t, k, v)
        newLoopThread(t, k)
    end})

    local newLoopObject = function(t,selff,f,fbreak)
        local fns = t.fns
        local fnsbreak = t.fnsbreak
        local f = f 
        local selff = selff
        local ref = function(act,val)
            if act == "break" or act == "kill" then 
                local n = fns and #fns or 0
                if n > 0 then 
                    for i=1,n do 
                        if fns[i] and fns[i] == f then 
                            table.remove(fns,i)
                            if fnsbreak and fnsbreak[i] then 
                                fnsbreak[i]() 
                                table.remove(fnsbreak,i)
                            end
                            
                            if #fns == 0 then 
                                table.remove(Loops[t.duration],i)
                            end
                            break
                        end
                    end
                else 
                    return t:delete(fbreak)
                end
            elseif act == "set" or act == "transfer" then 
                return t:transfer(val) 
            elseif act == "get" then 
                return t.duration
            elseif act == "self" then 
                return t
            end 
        end
        local aliveDelay = nil 
        return function(action,...)
            if not action then
                if aliveDelay and GetGameTimer() < aliveDelay then 
                    return e()
                else 
                    aliveDelay = nil 
                    return selff(ref)
                end
            elseif action == "setalivedelay" then 
                local delay = ...
                aliveDelay = GetGameTimer() + delay
            else 
                ref(action,...)
            end
        end 
    end 

    local LoopParty = function(duration,init)
        if not Loops[duration] then Loops[duration] = {} end 
        local self = {}
        self.duration = duration
        self.fns = {}
        self.fnsbreak = {}
        local selff
        if init then 
            selff = function(ref)
                local fns = self.fns
                local n = #fns
                if init() then 
                    for i=1,n do 
                        (fns[i] or e)(ref)
                    end 
                end 
            end 
        else 
            selff = function(ref)
                local fns = self.fns
                local n = #fns
                for i=1,n do 
                    (fns[i] or e)(ref)
                end 
            end 
        end 
        setmetatable(self, {__index = Loops[duration],__call = function(t,f,...)
            if type(f) ~= "string" then 
                local fbreak = ...
                table.insert(t.fns, f)
                if fbreak then table.insert(self.fnsbreak, fbreak) end
                local obj = newLoopObject(self,selff,f,fbreak)
                table.insert(Loops[duration], obj)
                self.obj = obj
                return self
            elseif self.obj then  
                return self.obj(f,...)
            end 
        end,__tostring = function(t)
            return "Loop("..t.duration..","..#t.fns.."), Total Thread: "..totalThread
        end})
        self.found = function(self,f)
            for i,v in ipairs(Loops[self.duration]) do
                if v == self.obj then
                    return i
                end 
            end 
            return false
        end
        self.delay = nil 
        local checktimeout = function(cb)
                
                if (self.delay and self.delay <= GetGameTimer()) or not self.delay then 
                    if Loops[duration] then 
                        local i = self.found(self)
                        if i then
                            local fns = self.fns
                            local fnsbreak = self.fnsbreak
                            local n = fns and #fns or 0
                            if n > 0 then 
                                table.remove(fns,n)
                                if fnsbreak and fnsbreak[n] then fnsbreak[n]() end
                                table.remove(fnsbreak,n)
                                if #fns == 0 then 
                                    table.remove(Loops[duration],i)
                                end
                                if cb then cb() end
                            elseif debugMode then  
                                error("It should be deleted")
                            end 
                            
                        elseif debugMode then  
                            error('Task deleteing not found',2)
                        end
                    elseif debugMode then  
                        error('Task deleteing not found',2)
                    end 
                end 
            end 
        self.delete = function(s,delay,cb)
            local delay = delay
            local cb = cb 
            if type(delay) ~= "number" then 
                cb = delay
                delay = nil 
            end 
            
            if delay and delay>0 then 
                self.delay = delay + GetGameTimer()   
                SetTimeout(delay,function()
                    checktimeout(cb)
                end)
            else
                self.delay = nil 
                checktimeout(cb)
            end 
        end
        self.transfer = function(s,newduration)
            if s.duration == newduration then return end
            local i = s.found(s) 
            if i then
                table.remove(Loops[s.duration],i)
                s.obj("setalivedelay",newduration)
                if not Loops[newduration] then Loops[newduration] = {} end 
                table.insert(Loops[newduration],s.obj)
                s.duration = newduration
            end
        end
        self.set = self.transfer 
        return self
    end 
    _M_.LoopParty = LoopParty
end 

LoopParty = _M_.LoopParty