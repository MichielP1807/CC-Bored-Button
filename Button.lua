local Pine3D = require("Pine3D")
local PineStore = require("pinestoreConsole")

local function presentButton()
  local SCREEN_WIDTH, SCREEN_HEIGHT = term.getSize()

  if periphemu then -- Attach speaker
    periphemu.create("top", "speaker")
  end
  ---@type Speaker
  local speaker = peripheral.find("speaker")


  local USED_COLORS = {
    colors.white,
    colors.lightGray,
    colors.gray,
    colors.black,
    colors.lightBlue,
    colors.blue,
    colors.red,
    colors.brown
  }
  local NEW_COLOR_VALUES = {
    0xf0f0f0,
    0xaaaaaa,
    0x898989,
    0x111111,
    0x84aef6,
    0x6a9bed,
    0xff3236,
    0xaf1315,
  }
  local OLD_COLOR_VALUES = {}

  for i = 1, #USED_COLORS do
    OLD_COLOR_VALUES[i] = {}
    local r, g, b = term.getPaletteColor(USED_COLORS[i])
    OLD_COLOR_VALUES[i][1] = r
    OLD_COLOR_VALUES[i][2] = g
    OLD_COLOR_VALUES[i][3] = b
    term.setPaletteColour(USED_COLORS[i], NEW_COLOR_VALUES[i])
  end

  local function resetPalette()
    for i = 1, #USED_COLORS do
      term.setPaletteColour(USED_COLORS[i], OLD_COLOR_VALUES[i][1], OLD_COLOR_VALUES[i][2], OLD_COLOR_VALUES[i][3])
    end
  end



  -- Enable mouse_move event (if config is available) (not in vanilla)
  local PREV_MOUSE_MOVE_THROTTLE
  if config then
    PREV_MOUSE_MOVE_THROTTLE = config.get("mouse_move_throttle")
    config.set("mouse_move_throttle", 10)
  end
  local function resetMouseMoveThrottle()
    -- Reset mouse_move throttle (by default -1 will disable mouse move event entirely)
    if config then
      config.set("mouse_move_throttle", PREV_MOUSE_MOVE_THROTTLE)
    end
  end



  local function resetEverything()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    resetPalette()
    resetMouseMoveThrottle()
  end

  local frame = Pine3D.newFrame()           -- x1, y1, x2, y2 (default is fullscreen)
  frame:setCamera(-7.07, 4.5, 0, 0, 0, -30) -- x, y, z, rotations around all axes (optional)
  frame:setFoV(50)                          -- set the field of view

  local backgroundModel = {}
  local spikes = 16;
  local TAU = 2 * math.pi
  local radius = 16
  for i = 0, spikes / 2 do
    backgroundModel[#backgroundModel + 1] = {
      x1 = 0,
      y1 = 0,
      z1 = 0,
      x2 = radius * math.sin(2 * i * TAU / spikes),
      y2 = 0,
      z2 = radius * math.cos(2 * i * TAU / spikes),
      x3 = radius * math.sin((2 * i + 1) * TAU / spikes),
      y3 = 0,
      z3 = radius * math.cos((2 * i + 1) * TAU / spikes),
      c = colors.blue,
      forceRender = true
    }
  end
  local background = frame:newObject(backgroundModel, 2, -1.2, 0, 0, 0, -TAU / 8)
  local button = frame:newObject("button.stab", 0, 0, 0, 0, TAU / 8, 0)
  local button_base = frame:newObject("button_base.stab", 0, 0, 0, 0, TAU / 8, 0)
  local objects = { button, button_base, background }

  local is_hovered = false      -- when user's cursor hovers over the button
  local is_pressed = false      -- when user is pressing the button
  local has_pressed = false     -- when user has pressed the button
  local has_mouse_moved = false -- in case they do not have mouse_move events
  local fade_complete = false
  local hover_start_time = 0
  local released_start_time = 0

  local button_y = 0

  local pleaseStartFunNowThanks = false
  local running = true
  local function userInput()
    while running do
      local event, which, x, y = os.pullEventRaw()
      if event == "mouse_move" then
        if x and y then
          has_mouse_moved = true
          local dx = x - 0.5 * SCREEN_WIDTH
          local dy = y - 0.5 * SCREEN_HEIGHT
          local hovered_over_button = math.sqrt(dx * dx + dy * dy) < 0.167 * SCREEN_WIDTH
          if not is_hovered and hovered_over_button then
            hover_start_time = os.clock()
          end
          is_hovered = hovered_over_button
        end
      elseif event == "mouse_click" then
        if (is_hovered or not has_mouse_moved) and not fade_complete then
          is_pressed = true
          if speaker then speaker.playSound("block.stone_button.click_on") end
        end
      elseif event == "mouse_up" then
        if is_pressed then
          is_pressed = false
          has_pressed = true
          released_start_time = os.clock()
          if speaker then speaker.playSound("block.stone_button.click_off") end
          -- if speaker then speaker.playSound("ui.toast.out") end
        end
      elseif event == "term_resize" then -- automatically resize
        SCREEN_WIDTH, SCREEN_HEIGHT = term.getSize()
        frame:setSize(1, 1, SCREEN_WIDTH, SCREEN_HEIGHT)
      elseif event == "terminate" then
        resetEverything()
        running = false
      end
    end
  end

  local function gameLoop()
    local lastTime = os.clock()
    local backgroundRad = 0
    local backgroundVelocity = 0.02

    while running do
      -- compute the time passed since last step
      local currentTime = os.clock()
      local dt = currentTime - lastTime
      lastTime = currentTime

      -- animate all the things that need to be animated
      local button_dir = is_pressed and -1 or 1
      button_y = button_y + button_dir * dt * 4
      button_y = math.max(math.min(button_y, 0), -0.3)
      button:setPos(0, button_y, 0)

      frame:setFoV(is_hovered and 45 - (math.sin((currentTime - hover_start_time) * 5) + 1) or 50)

      backgroundVelocity = is_hovered and 0.4 or 0.02
      backgroundRad = backgroundRad + dt * backgroundVelocity
      background:setRot(0, backgroundRad, -TAU / 8)

      local time_since_release = currentTime - released_start_time
      if has_pressed and time_since_release > 0.2 then
        -- fade to white
        for i = 1, #USED_COLORS do
          local r, g, b = term.getPaletteColor(USED_COLORS[i])
          r = math.min(r + 2 * dt, 1)
          g = math.min(g + 2 * dt, 1)
          b = math.min(b + 2 * dt, 1)
          term.setPaletteColor(USED_COLORS[i], r, g, b)
        end
        if time_since_release >= 0.5 then fade_complete = true end
        if time_since_release >= 2 then
          resetEverything()
          running = false
          pleaseStartFunNowThanks = true
        end
      else
        -- render stuff
        frame:drawObjects(objects)
        frame:drawBuffer()
      end


      -- use a fake event to yield the coroutine
      os.queueEvent("game-loop-pls")
      ---@diagnostic disable-next-line: param-type-mismatch
      os.pullEventRaw("game-loop-pls")
    end
  end


  parallel.waitForAll(userInput, gameLoop)

  return pleaseStartFunNowThanks
end

local function startFun()
  local project = PineStore.funProjects[math.random(#PineStore.funProjects)]

  local installed = PineStore.installedInfo.projects[tostring(project.id)]

  if not installed or project.version > installed.version then
    PineStore.installProject(project)
  end
  PineStore.startProject(project)
end


local function main()
  while true do
    if presentButton() then
      startFun()
    else
      return
    end
  end
end
main()
