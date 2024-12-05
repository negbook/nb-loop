local Module = {}
do
    local totalThreads = 0
    local DEBUG_MODE = false
    local emptyFunc = {} 
    setmetatable(emptyFunc, {__call = function(t,...) end})

    local function createLoopThread(table, key)
        CreateThread(function()
            totalThreads = totalThreads + 1
            local obj = table[key]
            repeat
                local tasks = (obj or emptyFunc)
                local taskCount = #tasks
                if taskCount == 0 then
                    goto endLoop
                end
                for i = 1, taskCount do
                    (tasks[i] or emptyFunc)()
                end
            until taskCount == 0 or Wait(key)
            ::endLoop::
            totalThreads = totalThreads - 1
            table[key] = nil
            return
        end)
    end

    -- 主要循環表,用於存儲所有循環任務
    local loopTable = setmetatable({[emptyFunc]=emptyFunc}, {
        __newindex = function(t, k, v)
            rawset(t, k, v)
            createLoopThread(t, k)
        end
    })

    -- 創建循環對象
    local function createLoopObject(loop)
        -- 內部變量
        local functions = {}      -- 存儲所有任務函數
        local breakFunctions = {} -- 存儲對應的中斷回調
        local selfFunction        -- 主執行函數
        local init = loop.init    -- 初始化條件
        local aliveDelay = nil    -- 存活延遲
        local shouldKill = false  -- 是否需要終止循環

        -- 內部刪除函數
        local function internalDelete(func)
            for i = 1, #functions do
                if functions[i] and functions[i] == func then
                    -- 執行並移除中斷回調
                    if breakFunctions[i] then
                        breakFunctions[i]()
                        table.remove(breakFunctions, i)
                    end
                    table.remove(functions, i)
                    break
                end
            end
            -- 如果沒有剩餘函數,從循環表中移除
            if #functions == 0 then
                table.remove(loopTable[loop.duration], loop:find())
            end
        end

        -- 引用函數處理器
        local ref = function(action, value, value2)
            if action == "internalDeleteFunction" then
                return internalDelete(value, value2)
            elseif action == "set" or action == "transfer" then
                return loop:transfer(value)
            elseif action == "get" then
                return loop.duration
            elseif action == "self" then
                return loop
            elseif action == "internalAddFunction" then
                table.insert(functions, value)
                if value2 then table.insert(breakFunctions, value2) end
            elseif action == "getInternalFunctions" then
                return functions
            elseif action == "kill" then
                shouldKill = true
            end
        end

        -- 為每個任務創建引用函數
        local function refFunction(func)
            return function(action, value)
                if action == "break" or action == "kill" then
                    return internalDelete(func)
                elseif action == "set" or action == "transfer" then
                    return loop:transfer(value)
                elseif action == "get" then
                    return loop.duration
                end
            end
        end

        -- 為init創建引用函數
        local initRef = function(action, value)
            if action == "kill" then
                shouldKill = true
            elseif action == "set" or action == "transfer" then
                return loop:transfer(value)
            elseif action == "get" then
                return loop.duration
            end
        end

        -- 根據是否有初始化條件創建主函數
        if init then
            selfFunction = function()
                local funcCount = #functions
                if not shouldKill and init(initRef) then
                    for i = 1, funcCount do
                        (functions[i] or emptyFunc)(refFunction(functions[i]))
                    end
                end
                if shouldKill then
                    for i = #functions, 1, -1 do
                        internalDelete(functions[i])
                    end
                end
            end
        else
            selfFunction = function()
                local funcCount = #functions
                for i = 1, funcCount do
                    (functions[i] or emptyFunc)(refFunction(functions[i]))
                end
            end
        end

        -- 返回主控制函數
        return function(action, ...)
            if not action then
                -- 檢查存活延遲
                if aliveDelay and GetGameTimer() < aliveDelay then
                    return emptyFunc()
                else
                    aliveDelay = nil
                    return selfFunction()
                end
            elseif action == "setAliveDelay" then
                local delay = ...
                aliveDelay = GetGameTimer() + delay
            else
                ref(action, ...)
            end
        end
    end

    -- 創建循環派對實例
    local function loopParty(duration, init)
        -- 初始化循環表
        if not loopTable[duration] then loopTable[duration] = {} end
        
        -- 創建實例對象
        local self = {
            duration = duration,
            delay = nil,
            init = init
        }

        -- 設置元表
        setmetatable(self, {
            __index = loopTable[duration],
            __call = function(t, func, ...)
                if type(func) ~= "string" then
                    -- 創建新的循環對象
                    if not self.obj then
                        local obj = createLoopObject(self)
                        table.insert(loopTable[duration], obj)
                        self.obj = obj
                    end
                    local breakFunc = ...
                    self.obj("internalAddFunction", func, breakFunc)

                    return {
                        parent = self,
                        delete = function() self.obj("internalDeleteFunction", func, breakFunc) end
                    }
                elseif self.obj then
                    return self.obj(func, ...)
                end
            end,
            __tostring = function(t)
                return "Loop("..t.duration..","..#t.obj("getInternalFunctions").."), Total Threads: "..totalThreads
            end
        })

        -- 查找函數
        self.find = function(self)
            for i, v in ipairs(loopTable[self.duration]) do
                if v == self.obj then return i end
            end
            return false
        end

        -- 超時檢查
        local function checkTimeout(callback)
            if not self.delay or (self.delay <= GetGameTimer()) then
                if loopTable[duration] then
                    local i = self.find(self)
                    if i then
                        table.remove(loopTable[duration], i)
                        if callback then callback() end
                    elseif DEBUG_MODE then
                        error('Task deleting not found', 2)
                    end
                elseif DEBUG_MODE then
                    error('Task deleting not found', 2)
                end
            end
        end

        -- 刪除方法
        self.delete = function(s, delay, callback)
            local delay = delay
            local callback = callback
            if type(delay) ~= "number" then
                callback = delay
                delay = nil
            end

            if delay and delay > 0 then
                self.delay = delay + GetGameTimer()
                CreateThread(function()
                    Wait(delay)
                    checkTimeout(callback)
                end)
            else
                self.delay = nil
                checkTimeout(callback)
            end
        end

        -- 轉移方法
        self.transfer = function(s, newDuration)
            if s.duration == newDuration then return end
            local i = s.find(s)
            if i then
                table.remove(loopTable[s.duration], i)
                s.obj("setAliveDelay", newDuration)
                if not loopTable[newDuration] then loopTable[newDuration] = {} end
                table.insert(loopTable[newDuration], s.obj)
                s.duration = newDuration
            end
        end

        -- 設置別名
        self.set = self.transfer
        return self
    end

    -- 導出模塊
    Module.loopParty = loopParty
end

LoopParty = Module.loopParty


