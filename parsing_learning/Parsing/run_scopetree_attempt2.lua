require("Parsing.parse_symboltree")
local S = LBSymbolTypes
local T = LBTokenTypes

--[[

    all we really want is to know what code is and isn't valie
    but how do we even remove things from a table defintion?
        and assignments that were never used?

    this is such a nightmare, even if we figure out which parts are actually used

    the fact some values will never be called is a nightmare


    can we treat local and global as tables as well?
    the scope table being special, in that we also search up higher for the values as well

    what happens if a table is only assigned into?
        that's a useless table isn't it?

    and same for any field that's not actually called during a useful call

    if we only assign into fields, and then it's safe to remove them all
        isn't it also safe to also remove the table itself?

    
    things we have:
        - a tree of syntax
        - knowledge of every table defintion, assignment, function definition, function call and time a value was used
        
    the basic level we're trying to remove is just "you literally never called this function"
        if we remove functions on that basis, then we can remove the variable they were assigned into as well
        and any other variable that ONLY holds that value

    the issue with resolving functions just once, is the values can rely on the inputs
    and the inputs may be different types each time (annoyingly)
    the reason that matters, is the difference of what functions may be getting passed in as lambdas
            and the difficulty of what tables are passed in with which fields

    some functions may be super generic, and take almost anything as input
            we want to track exactly which tables that is don't we

    each time we come across a definition, we need that value to be stored in the tree for next time
    is that right? probably

    because we want to tie the "stuff in the tree" to the "stuff that actually gets called"

    
]]



ValueTypes = {
    TABLE = "TABLE",
    FUNCTION = "FUNCTION",
    STRING = "STRING",
    NUMBER = "NUMBER",
    BOOL = "BOOL",
}
local V = ValueTypes

---@class Value
---@field type string
---@field symbol LBToken
Value = {
    ---@return Value
    new = function(this, type, symbol)
        return {
            type = type,
            symbol = symbol
        }
    end;
}

local K = {
    UNDEFINED_KEY = "__lbundefinedkeytype__",
    VALUE_KEY = "__lbvaluekeytype__",
    STRING_KEY = "__"
}

---@class TableValue : Value
---@field fields table<string, ValueCollection>
TableValue = {
    ---@return TableValue
    new = function(this, symbol)
        return {
            type = V.TABLE,
            symbol = symbol,
            fields = {},
            get = this.get,
            set = this.set
        }
    end;

    ---@return ValueCollection
    get = function(this, key)
        if not this.fields[key] then
            this.fields[key] = ValueCollection:new()
        end
        return this.fields[key]
    end;

    ---@param this TableValue
    ---@param value Value
    setKey = function(this, key, value)
        if not this.fields[key] then
            this.fields[key] = ValueCollection:new()
        end
        this.fields[key]:set(value)
    end;
}

---@class ValueCollection
---@field name string
---@field scope Scope
---@field isLocal boolean
---@field fields Value[]
---@field symbolsLookup table<LBToken, boolean>
ValueCollection = {
    ---@return ValueCollection
    new = function(this)
        return {
            symbolsLookup = {},

            -- functions
            isNil = this.isNil,
            isValueType = this.isValueType,
            assignTableKey = this.assignTableKey,
            getTablesWithKey = this.getTablesWithKey,
            getFunctions = this.getFunctions,
            getTables = this.getTables,
            combine = this.combine
        }
    end;

    ---@param value Value
    ---@param this ValueCollection
    set = function(this, value)
        if not this.symbolsLookup[value.symbol] then
            this.symbolsLookup[value.symbol] = true
            this[#this+1] = value
        end
        this[#this+1] = value
    end;

    ---@param value Value
    ---@return ValueCollection
    setKey = function(this, key, value)
        for i=1,#this do
            local val = this[i]
            if val.type == V.TABLE then
                val.set(key, value)
            end
        end
    end;



    ---@return boolean
    isNil = function(this)
        return #this == 0
    end;

    ---@return boolean
    isValueType = function(this)
        for i=1,#this do
            if this[i].type == V.FUNCTION or this[i].type == V.TABLE then
                return false
            end
        end
        return true
    end;

    ---@return ValueCollection
    getTables = function(this)
        local result = ValueCollection:new()
        for i=1,#this do
            local val = this[i]
            if val.type == V.TABLE then
                result:set(val)
            end
        end
        return result
    end;

    ---@return ValueCollection
    getTablesWithKey = function(this, key)
        local result = ValueCollection:new()
        for i=1,#this do
            local val = this[i]
            if val.type == V.TABLE and val.get(key) then
                result:set(val)
            end
        end
        return result
    end;

    ---@return ValueCollection
    getFunctions = function(this)
        local result = ValueCollection:new()
        for i=1,#this do
            local val = this[i]
            if val.type == V.FUNCTION then
                result:set(val)
            end
        end
        return result
    end;

    ---@param this ValueCollection
    ---@return ValueCollection
    combine = function(this, valueCollection)
        for i=1,#valueCollection do
            this:set(valueCollection[i])
        end
        return this
    end;
}

---@class Scope : TableValue
---@field parent Scope
---@field locals TableValue
---@field _ENVCollection ValueCollection collection of all the values _ENV can be (can be not a table too)
Scope = {
    ---@param this Scope
    ---@return Scope
    new = function(this)
        local scope = {
            parent = nil,
            locals = TableValue:new(),
            _ENVCollection = ValueCollection:new(), -- env itself can be redefined, which would be a real PITA

            --functions
            newChildScope = this.newChildScope,
            get = this.get,
        }
        scope._ENV[#scope._ENV+1] = TableValue:new()
    end;

    ---@param this Scope
    ---@return Scope
    newChildScope = function(this)
        local scope = {
            parent = this,
            locals = {},

            --functions
            get = this.get,
        }

        this[#this+1] = scope
        return scope
    end;

    ---@param this Scope
    ---@param key string
    ---@return ValueCollection
    get = function(this, key)
        if this.locals[key] then
            return this.locals[key]
        elseif this.parent then
            return this.parent:get(key)
        end

        -- no parent, so is a global from _ENV
        if key == "_ENV" then
            return this._ENVCollection -- request for the _ENV table directly
        else
            return this._ENVCollection:getTablesWithKey(key)
        end
        -- note, expected use is:
        --      e.g. a.b.c = 123
        --      => get(a).get(b).set(c, 123)

        -- or,
        --      a = 123
        --      => set(a, 123)
    end;

    set = function(this, key, valueCollection)
        this._ENVCollection:getTables():set(key, valueCollection)
    end;

    ---@param this Scope
    setLocal = function(this, key, valueCollection)
        this.locals:set(key, valueCollection)
    end;
}


-- the reason we want this, over the other one?
---@class ScopedTree
---@field parent ScopedTree
---@field parentIndex number
---@field symbol LBToken
---@field [number] ScopedTree
ScopedTree = {
    ---@param this ScopedTree
    ---@return ScopedTree
    newFromSymbol = function(this, symbol, parent, parentIndex)
        local this = {
            -- fields
            parent = parent,
            parentIndex = parentIndex,
            symbol = symbol,

            -- functions
            replaceSelf     = this.replaceSelf,
            sibling         = this.sibling,
            siblingsUntil   = this.siblingsUntil,
            next            = this.next,
            nextInstanceOf  = this.nextInstanceOf,
            nextUntil       = this.nextUntil
        }

        for i=1,#this.symbol do
            this[#this+1] = ScopedTree:newFromSymbol(this.symbol[i], this, i)
        end

        return this;
    end;

    is = function(this, ...)
        return is(this.symbol.type, ...)
    end;

    ---@param this ScopedTree
    ---@param replacementSymbol LBToken
    replaceSelf = function(this, replacementSymbol)
        this.parent.symbol[this.parentIndex] = replacementSymbol
    end;

    ---@param this ScopedTree
    ---@return ScopedTree
    has = function(this, ...)
        for i=1, #this do
            if is(this[i].symbol.type, ...) then
                return this[i]
            end
        end
        return nil
    end;

    --- Enters the child chain, just *before* the first element
    --- Makes it easier to iterate the child nodes
    ---@param this ScopedTree
    ---@return ScopedTree
    getChildSiblingStart = function(this)
        if #this then
            return ScopedTree:newFromSymbol(LBToken:new("NONE"), this, 0)
        end
        return nil
    end;

    ---@param this ScopedTree
    ---@return ScopedTree
    next = function(this, i)
        i = i or 1
        if i == 0 then
            return this, 0
        else
            i = i - 1
            local found
            for iChildren=1, #this do
                found, i = next(this[iChildren], i)
                if i == 0 then
                    return found, 0
                end
            end
            return nil, i
        end
    end;

    ---@param this ScopedTree
    ---@return ScopedTree[]
    nextUntil = function(this, ...)
        local _nextUntil;
        _nextUntil = function(this, found, ...)
            if is(this.symbol.type, ...) then
                return found, true
            else
                found[#found+1] = this

                for iChildren=1, #this do
                    local childrenFound, wasFound = _nextUntil(this[iChildren], found, ...)

                    if wasFound then
                        return found, true
                    end
                end
                return found, false
            end
        end;

        local result = _nextUntil(this, {}, ...)

        -- clip off self from the front of the list, as we're only wanting the "next" stuff
        if #result > 1 then
            table.remove(result, 1)    
        end
        return result
    end;
    

    ---@param this ScopedTree
    ---@return ScopedTree
    nextInstanceOf = function(this, ...)
        if is(this.symbol.type, ...) then
            return this
        else
            local found
            for iChildren=1, #this do
                found = this[iChildren]:nextInstanceOf(...)
                if found then
                    return found
                end
            end
            return nil
        end
    end;

    ---@param this ScopedTree
    ---@return ScopedTree
    sibling = function(this, i)
        i = i or 1
        return this.parent[this.parentIndex + i]
    end;

    ---@param this ScopedTree
    ---@return ScopedTree[]
    siblingsUntil = function(this, ...)
        local siblings = {}
        for i=this.parentIndex+1, #this.parent do
            if not is(this.parent[i].symbol.type, ...) then
                siblings[#siblings+1] = this.parent[i]
            else
                return siblings, this.parent[i]
            end
        end
        return siblings, nil
    end;
}



---@param scope Scope
---@param tree ScopedTree
walkBody = function(tree, scope)
    local returnValues = {}

    for i=1,#tree do
        local val = tree[i]
        if is(val.symbol.type, S.GLOBAL_ASSIGNMENT) then
            -- some variable is being set in some scope
            resolveAssignmentChain(val, scope)
        elseif is(val.symbol.type, S.EXPCHAIN) then
            walkSideEffectsOnly(val, scope)


        elseif is(val.symbol.type, S.GLOBAL_NAMEDFUNCTIONDEF) then
            -- some variable is being set in some scope
            resolveNamedFunctionDef(val, scope)

        elseif is(val.symbol.type, S.LOCAL_NAMEDFUNCTIONDEF) then
            -- some variable is being set in some scope
            resolveLocalNamedFunctionDef(val, scope)


        elseif is(val.symbol.type, S.LOCAL_ASSIGNMENT) then
            -- some variable is being set in some scope
            resolveLocalAssignmentChain(val, scope)

        elseif is(val.symbol.type, S.FOR_LOOP, S.IF_STATEMENT, S.WHILE_LOOP, S.REPEAT_UNTIL, S.DO_END) then
            -- new local scope
            --returnValues:combine(resolveBody(val, scope:branch()))
        elseif is(val.symbol.type, T.RETURN) then
            -- add the return values to the things we're returning
        end
    end

    return returnValues
end;

walkSideEffectsOnly = function(tree, scope)
    local returnValues = ValueCollection:new()

    for i=1,#tree do
        local child = tree[i]
        if is(child.symbol.type, S.EXPCHAIN) then
            resolveExpChain(child, scope) -- ignore the return value
        end
        walkSideEffectsOnly(child)
    end
    return returnValues
end;


-- walk means "run through these"
-- resolve means "get me the return type"?
-- do we need it for everything?
-- is an operator chain still needed?

-- why are we handling named functs differently from each other


-- resolves the value type for inner square brackets
---@param tree ScopedTree
---@return Value
getKeyFromSquareBrackets = function (tree, scope)
    local innerSymbol = tree:next(2)
    if innerSymbol:is(T.STRING) then
        return innerSymbol.symbol.stringContent

    elseif innerSymbol:is(S.STRINGCHAIN) then
        return K.UNDEFINED_KEY -- could be any string key

    elseif innerSymbol:is(S.NUMCHAIN, T.NUMBER, S.BOOLCHAIN, T.TRUE, T.FALSE) then
        return K.VALUE_KEY

    else
        local resolvedValues = resolveValueElement(innerSymbol, scope)

        -- if we end up with *just* value types, then we're ok
        -- if we end up with unreliable types, then we're 
        if resolvedValues:isHomogenous() then
            -- something
        else
            return K.UNDEFINED_KEY
        end
    end
end

---@param scope Scope
---@param tree ScopedTree
resolveNamedFunctionDef = function(tree, scope)
    -- sets variable value to the function
    local functionKeyword = tree:nextInstanceOf(T.FUNCTION)
    local identchain = functionKeyword:siblingsUntil(S.FUNCTIONDEF_PARAMS)

    -- note, in named functions identchain is always just identifiers + (./:) access, no expression
    local isSelf = #identchain > 1 and identchain[#identchain-1].symbol.type == T.COLONACCESS

    -- this is the actual variable (if it's a chain, this must be a table)
    local baseVariable = scope:get(identchain[1].symbol.raw)
    for i=2,#identchain do
        local ident = identchain[i]
        if ident.symbol.type == T.IDENTIFIER then
        elseif ident.symbol.type == T.DOTACCESS then
        elseif ident.symbol.type == S.SQUARE_BRACKETS then
            local key = getKeyFromSquareBrackets(ident)
        end
    end


    if baseVariable.is(V.TABLE) then
        local tableVals = baseVariable.valuesOfType(V.TABLE) -- TODO: write a wrapper that avoids insane duplication (lots of inner loops)
        
        -- we kind of need to branch here, for each variable that's in the table; no?
        -- or we need to handle this in a more sensible way somehow
        -- we can't force type checking, if we don't know for sure what value is in this
        -- or do we handle tables as just another scope?
        -- and variables like some kind of chainable thing?
        -- or we keep it "simple" and concat the names, into the global table?
        -- so everything is still a flat style value
        -- the issue, is putting that all back together

        -- on table definitions, we need to make a new table
        -- we need to share the instance of that table/find where it's used etc.
        local vars = tableVals:get()
        for i=3, #identchain,2 do
            if identchain[i].symbol.type == T.IDENTIFIER then
    
            end
        end

    else
        if #identchain > 1 then
            error("cannot use . notation on non-table value " .. baseVariable.name)
        end


    end
end;

---@param scope Scope
---@param tree ScopedTree
resolveLocalNamedFunctionDef = function(tree, scope)
    -- sets variable value to the function
    local functionKeyword = tree:nextInstanceOf(T.FUNCTION)
    local identifier = functionKeyword:nextInstanceOf(T.IDENTIFIER)

    local identname = identifier.symbol.raw
    local variable = scope:newLocal(identname)

    variable:assign("FUNCTIONDEF", tree)
end;

resolveValueElement = function(tree, scope)
    local valueCollection = ValueCollection:new()
    if is(tree.symbol.type, S.BOOLCHAIN) then
        valueCollection[#valueCollection+1] = Value:new(V.BOOL, tree.symbol)
        walkSideEffectsOnly(tree, scope)

    elseif is(tree.symbol.type, S.NUMCHAIN) then
        valueCollection[#valueCollection+1] = Value:new(V.NUMBER, tree.symbol)
        walkSideEffectsOnly(tree, scope)

    elseif is(tree.symbol.type, S.STRINGCHAIN) then
        valueCollection[#valueCollection+1] = Value:new(V.STRING, tree.symbol)
        walkSideEffectsOnly(tree, scope)

    end
end;

---@param tree ScopedTree
resolveOrChain = function(tree, scope)
    local returnValues = ValueCollection:new()

    -- right now we just assume all the branches could be true
    -- in future, could add it that we check if the condition can't possibly be true?
    -- maybe all this was a bit of a silly endeavor
    for i=1,#tree, 2 do
        local child = tree[i]
        local returnVal = resolveValueElement(child)
        returnValues:combine(returnVal)
    end
    return returnValues
end;

---@param tree ScopedTree
resolveAndChain = function(tree, scope)
    local returnValues = ValueCollection:new()

    for i=1,#tree, 2 do
        local child = tree[i]
        local returnVal = resolveValueElement(child)
        returnValues:combine(returnVal)
    end
    return returnValues
end;

--- function calls, a.b.c():def() etc.
---@param tree ScopedTree
resolveExpChain = function(tree, scope)
    local returnValues = ValueCollection:new()

    for i=1,#tree, 2 do
        local child = tree[i]
        local returnVal = resolveValueElement(child)
        returnValues:combine(returnVal)
    end
    return returnValues
end;



---@param scope Scope
---@param tree ScopedTree
resolveAssignmentChain = function(tree, scope)
    -- sets variable value
    local lvalues = tree:nextUntil(T.ASSIGN)
end;

---@param scope Scope
---@param tree ScopedTree
resolveLocalAssignmentChain = function(tree, scope)
    -- sets variable value
    local identChain = tree:nextInstanceOf(T.LOCAL):siblingsUntil(T.ASSIGN)

    local variablesToAssign = {}
    for i=1,#identChain do
        if identChain[i].symbol.type == T.IDENTIFIER then
            local identName = identChain[i].symbol.raw
            variablesToAssign[#variablesToAssign+1] = scope:newLocal(identName)
        end
    end

    local assign = identChain[#identChain]:nextInstanceOf(T.ASSIGN)
    if assign then
        local rvalues = identChain:siblingsUntil()

    end
end;
