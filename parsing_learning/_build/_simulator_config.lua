--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

---@section onLBSimulatorTick

-- Set properties and screen sizes here - will run once when the script is loaded
simulator:setScreen(1, "3x3")
simulator:setProperty("ExampleBoolProperty", true)
simulator:setProperty("ExampleNumberProperty", 123)
simulator:setProperty("ExampleTextProperty", "Text")

-- Runs every tick just before onTick; allows you to simulate the inputs changing
---@param simulator Simulator Use simulator:<function>() to set inputs etc.
---@param ticks number Number of ticks since simulator started
function onLBSimulatorTick(simulator, ticks)
    simulator:setInputBool(20, ticks % 60 < 30)             -- example, bool that flips on/off every 30 ticks (0.5 seconds)
    simulator:setInputNumber(20, ticks)                     -- example, set input 20 to the number of ticks
    simulator:setInputNumber(21, math.sin(ticks%60 / 60))   -- example, sin wave that oscillates every 60 ticks (1 second)
    

    -- default touchscreen connection
    screenConnection = simulator:getTouchScreen(1)
    if ticks < 120 then
        simulator:setInputBool(1,   0)
        simulator:setInputBool(2,   0)
        simulator:setInputNumber(1, 0)
        simulator:setInputNumber(2, 0)
        simulator:setInputNumber(3, 0)
        simulator:setInputNumber(4, 0)
        simulator:setInputNumber(5, 0)
        simulator:setInputNumber(6, 0)
    else

    simulator:setInputBool(1,   screenConnection.isTouched)
    simulator:setInputBool(2,   screenConnection.isTouchedAlt)
    simulator:setInputNumber(1, screenConnection.width)
    simulator:setInputNumber(2, screenConnection.height)
    simulator:setInputNumber(3, screenConnection.touchX)
    simulator:setInputNumber(4, screenConnection.touchY)
    simulator:setInputNumber(5, screenConnection.touchAltX)
    simulator:setInputNumber(6, screenConnection.touchAltY)
    end
end;
---@endsection