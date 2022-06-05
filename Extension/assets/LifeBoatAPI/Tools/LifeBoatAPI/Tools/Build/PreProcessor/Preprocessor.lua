-- Author: Nameous Changey
-- GitHub: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension
-- Workshop: https://steamcommunity.com/id/Bilkokuya/myworkshopfiles/?appid=573090
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

require("LifeBoatAPI.Tools.Utils.Base")
require("LifeBoatAPI.Tools.Utils.TableUtils")
require("LifeBoatAPI.Tools.Utils.StringBuilder")
require("LifeBoatAPI.Tools.Utils.StringUtils")



---@class PreProcessor : BaseClass
---@field tags ProcessorTag[]
LifeBoatAPI.Tools.PreProcessor = {
    _TagPattern = "%-%-%-@lb%(([^,)]*),?([^,)]*),?([^,)]*),?([^,)]*),?([^,)]*),?([^,)]*),?([^,)]*),?([^,)]*),?([^),]*),?([^,)]*)%)[^\n]*\n";
    TagPattern = "%-%-%-@lb%(([^\n]*)%)[^\n]*\n";

    new = function (cls)
        local this = LifeBoatAPI.Tools.BaseClass.new(cls)
        this.tagFactories = {}
        this.tags = {}
        this.maxIterations = 10000
        return this
    end;

    register = function(this, name, factory)
        this.tagFactories[name] = factory
    end;

    process = function(this, text)
        return this:run(text, function(tag, text) return tag:process(text) end)
    end;

    cleanup = function(this, text)
        return this:run(text, function(tag, text) return tag:cleanup(text) end)
    end;

    run = function(this, text, processFunction)
        local changesMade = false
        local iterations = 0
        repeat
            changesMade = false
            iterations = iterations + 1

            this.tags = this:_findAndInitializeTags(text)
            for i=1, #this.tags do
                local tag = this.tags[i]
                local newText = processFunction(tag, text)
                
                if newText then
                    text = newText
                    changesMade = true
                    break
                end
            end
        until(not changesMade or iterations > this.maxIterations)
  

        if iterations > this.maxIterations then
            error("Please check ---@lb() processor tags, especially macros, for recursive content. Exceeded max processor passes. Cancelling build.")    
        end

        return text
    end;

    _findAndInitializeTags = function(this, text)
        local tags = {}

        local tagMatches = LifeBoatAPI.Tools.StringUtils.find(text, this.TagPattern)

        for i=1, #tagMatches do
            local match = tagMatches[i]

            -- parse the captures manually, so we can have nested brackets
            local captures = this:_parseCaptures(match.captures[1])

            
            match.captures = captures

            local tag = LifeBoatAPI.Tools.ProcessorTag:new(i, match)
            local mappedTag = this:_mapTag(tag)
            tags[#tags+1] = mappedTag
        end

        return tags
    end;

    _parseCaptures = function(this, captureString)
        local captures = {}
        local brackets = 0
        local currentCapture = ""
        for j=1, #captureString do
            local c = captureString:sub(j,j)
            if brackets == 0 and c == "," then
                captures[#captures+1] = currentCapture
                currentCapture = ""
            elseif c == ")" then
                brackets = brackets - 1
                currentCapture = currentCapture .. c
                if brackets == -1 then
                    error("Format error, too many closing brackets in tag: " .. captureString)
                end
            elseif c == "(" then
                brackets = brackets + 1
                currentCapture = currentCapture .. c
            else
                currentCapture = currentCapture .. c
            end
        end

        captures[#captures+1] = currentCapture

        if brackets > 0 then
            error("Format error, missing closing bracket in tag: " .. captureString)
        end

        return captures
    end;

    _mapTag = function(this, tag)
        if this.tagFactories[tag.type] then
            return this.tagFactories[tag.type]:create(this,tag) or tag
        end
        return tag -- no additional rules found, use default mapping
    end;

    ---@return ProcessorTag
    getTag = function(this, index)
        return this.tags[index]
    end;

    ---@return ProcessorTag
    getNextTagWhere = function(this, startIndex, predicate)
        if startIndex < #this.tags then
            for i=startIndex, #this.tags do
                local tag = this.tags[i]
                if predicate(tag) then
                    return tag
                end
            end
        end
        return nil
    end;
}

---@class ProcessorTag : BaseClass
---@field startIndex number
---@field endIndex number
---@field args string[]
---@field type string
---@field index number
LifeBoatAPI.Tools.ProcessorTag = {
    ---example: ---@lb(arg1,arg2,arg3,...arg10) note no spaces between each argument
    ---example: ---@lb(arg1,arg2,arg3,...arg10) note no spaces between each argument
    ---@param cls ProcessorTag
    ---@param match StringMatch
    ---@return ProcessorTag
    new = function(cls, i, match)
        local this = LifeBoatAPI.Tools.BaseClass.new(cls)

        this.priorty = 0; -- lowest priority
        this.type = (match.captures[1] or ""):lower()
        this.index = i
        this.args = {}

        for i=2, #match.captures do
            this.args[i-1] = match.captures[i] ~= "" and match.captures[i] or nil
        end

        this.startIndex = match.startIndex
        this.endIndex = match.endIndex
        return this
    end;

    process = function() end;

    cleanup = function(tag, text)
        tag.cleanup = function(tag, text)
            return LifeBoatAPI.Tools.StringUtils.replaceIndex(text, tag.startIndex, tag.endIndex)
        end;
    end;
}
LifeBoatAPI.Tools.Class(LifeBoatAPI.Tools.ProcessorTag)