hs.hotkey.bind({"cmd"}, "G", function()
    -- Check if clipboard already contains a curl command with the desired URL pattern
    local original = hs.pasteboard.getContents()
    if not original or not original:match("curl%s+['\"]https?://[^%s]+%.axleaccess%.com") then
        -- If not, simulate copy to get highlighted text
        hs.eventtap.keyStroke({"cmd"}, "c")
        
        -- Short pause to ensure copy completes
        hs.timer.usleep(100000)  -- 0.1 second
        
        -- Get the new clipboard contents
        original = hs.pasteboard.getContents()
    end

    if original then
        -- Replace the URL (first occurrence only)
        local modified = original:gsub("(https?://[^%s]+%.axleaccess%.com)", "http://localhost:6969", 1)
        
        -- Add jq for pretty printing JSON output, but fallback to raw output if not JSON
        modified = modified .. " | (jq '.' 2>/dev/null || cat)"
        
        -- Copy modified text to clipboard
        hs.pasteboard.setContents(modified)
        
        -- Debug: Print modified content
        print("Modified content: " .. modified)
        
        -- Activate Terminal (or iTerm, change 'Terminal' to 'iTerm' if needed)
        hs.application.launchOrFocus("Terminal")
        
        -- Wait .5 seconds for the terminal to activate
        hs.timer.usleep(500000)
        
        -- Paste the modified command using cmd+v
        hs.eventtap.keyStroke({"cmd"}, "v")
        
        -- Short pause before hitting enter
        hs.timer.usleep(100000)
        
        -- Press Return to execute
        hs.eventtap.keyStroke({}, "return")
        
        hs.alert.show("Command pasted and executed")
    else
        hs.alert.show("No content in clipboard or no matching URL found")
    end
end)

-- Mouse button handling for DeathAdder
local lastClickTime = 0
local clickCount = 0
local MULTI_CLICK_TIME = 0.4  -- Increased window for multiple clicks
local lastSwipeTime = 0
local SWIPE_COOLDOWN = 0.08  -- Reduced cooldown between swipes
local isSwipeInProgress = false
local lastSuccessfulSwipe = 0
local RECOVERY_TIMEOUT = 2.0  -- Time to wait before auto-recovery

-- Function to reset the event tap
local function resetEventTap()
    if mouseButtons then
        mouseButtons:stop()
        hs.timer.usleep(100000)  -- Wait 100ms
        mouseButtons:start()
        print("Event tap reset")
    end
end

-- Function to simulate swipe using AppleScript
local function simulateSwipe(direction)
    if isSwipeInProgress then
        print("Swipe in progress, ignoring")
        return false
    end

    -- Prevent swipes that are too close together
    local currentTime = hs.timer.secondsSinceEpoch()
    if (currentTime - lastSwipeTime) < SWIPE_COOLDOWN then
        print("Swipe ignored - too soon after last swipe")
        return false
    end

    -- Check if we need recovery
    if (currentTime - lastSuccessfulSwipe) > RECOVERY_TIMEOUT then
        resetEventTap()
    end

    lastSwipeTime = currentTime
    isSwipeInProgress = true

    -- Debug alert
    print("Simulating swipe: " .. direction)
    
    local script
    if direction == 'left' then
        script = [[
            tell application "System Events"
                -- Ensure modifier keys are released
                key up {command, control, option, shift}
                delay 0.02
                key code 123 using {control down}
                delay 0.02
                key up {control}
            end tell
        ]]
    else
        script = [[
            tell application "System Events"
                -- Ensure modifier keys are released
                key up {command, control, option, shift}
                delay 0.02
                key code 124 using {control down}
                delay 0.02
                key up {control}
            end tell
        ]]
    end
    
    -- Execute AppleScript with error handling
    local ok, result = pcall(function()
        return hs.osascript.applescript(script)
    end)
    
    isSwipeInProgress = false
    
    if ok then
        lastSuccessfulSwipe = currentTime
        return true
    else
        print("AppleScript error: " .. tostring(result))
        -- Try to recover immediately if there's an error
        resetEventTap()
        return false
    end
end

-- Queue for pending swipes
local swipeQueue = {}
local isProcessingQueue = false

-- Function to process the swipe queue
local function processSwipeQueue()
    if isProcessingQueue or #swipeQueue == 0 then return end
    
    isProcessingQueue = true
    while #swipeQueue > 0 do
        local direction = table.remove(swipeQueue, 1)
        simulateSwipe(direction)
        hs.timer.usleep(80000)  -- 80ms between queued swipes
    end
    isProcessingQueue = false
end

-- Create event tap for mouse buttons with error handling
local function createMouseButtonHandler()
    return hs.eventtap.new({hs.eventtap.event.types.otherMouseDown}, function(e)
        local buttonPressed = e:getProperty(hs.eventtap.event.properties['mouseEventButtonNumber'])
        local currentTime = hs.timer.secondsSinceEpoch()
        
        -- Handle side buttons (confirmed as 3 and 4 for DeathAdder)
        if buttonPressed == 3 or buttonPressed == 4 then
            -- Check for multiple clicks with more lenient timing
            if (currentTime - lastClickTime) <= MULTI_CLICK_TIME then
                clickCount = math.min(clickCount + 1, 4)  -- Cap at quadruple-click
            else
                clickCount = 1
            end
            
            lastClickTime = currentTime
            
            -- Queue up swipes based on click count
            local direction = buttonPressed == 3 and 'left' or 'right'
            for i = 1, clickCount do
                table.insert(swipeQueue, direction)
            end
            
            -- Start processing the queue
            processSwipeQueue()
            
            return true
        end
        return false
    end)
end

-- Create the event tap
mouseButtons = createMouseButtonHandler()

-- Start watching for mouse events
mouseButtons:start()

-- Create a watchdog timer to check and reset if needed
local function watchdog()
    local currentTime = hs.timer.secondsSinceEpoch()
    if (currentTime - lastSuccessfulSwipe) > RECOVERY_TIMEOUT and not isSwipeInProgress then
        resetEventTap()
    end
end

-- Run the watchdog every 2 seconds
hs.timer.doEvery(2, watchdog)

-- Alert to show the script has been loaded
hs.alert.show("DeathAdder mouse buttons configured for rapid swipes")