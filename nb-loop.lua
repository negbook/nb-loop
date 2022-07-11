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

    local newLoopObject = function(t)
        local fns = {}
        local fnsbreak = {}
        local selff
        local init = t.init 
        
        local internal_delete = function(f)
            
            for i=1,#fns do 
                if fns[i] and fns[i]==f then 
                    table.remove(fns,i)
                    if fnsbreak[i] then 
                        fnsbreak[i]()
                        table.remove(fnsbreak,i)
                    end 
                    
                end 
            end 
            if #fns == 0 then 
                table.remove(Loops[t.duration],t:found())
            end
        end     
        local ref;ref = function(act,val,val2)
            if act == "internal_deletefunction" then 
                return internal_delete(val,val2)
            elseif act == "set" or act == "transfer" then 
                return t:transfer(val) 
            elseif act == "get" then 
                return t.duration
            elseif act == "self" then 
                return t
            elseif act == "internal_addfunction" then 
                table.insert(fns, val)
                if val2 then table.insert(fnsbreak, val2) end
            elseif act == "get_internal_functions" then 
                return fns
            end 
        end
        
        local ref_f = function(f)
             return function(act,val)
                if act == "break" or act == "kill" then 
                     return internal_delete(f)
                 elseif act == "set" or act == "transfer" then 
                     return t:transfer(val) 
                 elseif act == "get" then 
                     return t.duration
                 end 
             end 
         end
        
        if init then 
            selff = function()
                local n = #fns
                if init() then 
                    for i=1,n do 
                        (fns[i] or e)(ref_f(fns[i]))
                    end 
                end 
            end 
        else 
            selff = function()
                local n = #fns
                for i=1,n do 
                    (fns[i] or e)(ref_f(fns[i]))
                end 
            end 
        end 
        
        local aliveDelay = nil 
        return function(action,...)
            if not action then
                if aliveDelay and GetGameTimer() < aliveDelay then 
                    return e()
                else 
                    aliveDelay = nil 
                    return selff()
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
        setmetatable(self, {__index = Loops[duration],__call = function(t,f,...)
            if type(f) ~= "string" then 
                if not self.obj then 
                    local obj = newLoopObject(self)
                    table.insert(Loops[duration], obj)
                    self.obj = obj
                end 
                local fbreak = ...
                self.obj("internal_addfunction",f,fbreak)
                
                return {
                    parent = self,
                    delete = function() self.obj("internal_deletefunction",f,fbreak) end    
                }
            elseif self.obj then  
                return self.obj(f,...)
            end 
        end,__tostring = function(t)
            return "Loop("..t.duration..","..#t.obj("get_internal_functions").."), Total Thread: "..totalThread
        end})
        self.found = function(self)
            for i,v in ipairs(Loops[self.duration]) do
                if v == self.obj then
                    return i
                end 
            end 
            return false
        end
        self.delay = nil 
        local checktimeout = function(cb)
                
                if not self.delay or (self.delay <= GetGameTimer()) then 
                    if Loops[duration] then 
                        local i = self.found(self)
                        if i then
                            table.remove(Loops[duration],i)
                            if cb then cb() end
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
                CreateThread(function()
                    Wait(delay) 
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