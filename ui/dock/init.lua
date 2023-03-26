local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local wibox = require("wibox")
local gears = require("gears")
local helpers = require("helpers")
local iconTheme = require("theme.colors").iconTheme
local beautiful = require("beautiful")
local getIcon = require("ui.dock.getIcon")
local drawPreview = require("ui.dock.taskpreview")

local tomfoolery = function(s)
  local dock = awful.popup {
    widget = wibox.container.background,
    ontop = true,
    bg = beautiful.bg,
    visible = true,
    screen = s,
    type = "dock",
    height = 150,
    width = 500,
    placement = function(c) awful.placement.bottom(c, { margins = dpi(10) }) end,
    shape = helpers.rrect(10)
  }
  local function check_for_dock_hide()
    for _, client in ipairs(s.selected_tag:clients()) do
      if client.fullscreen then
        dock.visible = false
      end
    end
    if #s.selected_tag:clients() < 1 then
      dock.visible = true
      return
    end
    if s == mouse.screen then
      local minimized
      for _, c in ipairs(s.selected_tag:clients()) do
        if c.minimized then
          minimized = true
        end
        if c.maximized or c.fullscreen then
          dock.visible = false
          return
        end
        if not c.minimized then
          local y = c:geometry().y
          local h = c.height
          if (y + h) >= s.geometry.height - 85 then
            dock.visible = false
            return
          else
            dock.visible = true
          end
        end
      end
      if minimized then
        dock.visible = true
      end
    else
      dock.visible = false
    end
  end
  local dockHide = gears.timer {
    timeout = 1,
    autostart = true,
    call_now = true,
    callback = function()
      check_for_dock_hide()
    end
  }
  dockHide:again()

  local hotpop = wibox({
    type = "dock",
    height = beautiful.useless_gap * 3,
    width = 100,
    screen = s,
    ontop = true,
    visible = true,
    bg = beautiful.bg .. '00'
  })

  awful.placement.bottom(hotpop)
  hotpop:setup {
    widget = wibox.container.margin,
    margins = 10,
    layout = wibox.layout.fixed.vertical
  }


  local createPermaElement = function(icon, cmd)
    return wibox.widget {
      forced_height = 50,
      forced_width = 50,
      image = iconTheme .. icon,
      clip_shape = helpers.rrect(8),
      buttons = {
        awful.button({}, 1, function()
          awful.spawn.with_shell(cmd)
        end)
      },
      widget = wibox.widget.imagebox,
    }
  end

  local createPermaElements = function()
    local launcher = createPermaElement("/apps/scalable/search.svg", "rofi -show drun")
    local settings = createPermaElement("/apps/scalable/gdm-settings.svg",
      "awesome-client 'awesome.emit_signal(\"toggle::control\")'")
    local trash = createPermaElement("/places/scalable/gnome-dev-trash-full.svg", "nemo .local/share/Trash/files")
    return wibox.widget {
      {
        launcher,
        settings,
        trash,
        spacing = 7,
        layout = wibox.layout.fixed.horizontal
      },
      widget = wibox.container.margin,
      left = 7
    }
  end

  local createDockIndicators = function(data)
    local clients = data.clients
    local indicators = wibox.widget { layout = wibox.layout.flex.horizontal, spacing = 4 }
    for i, v in ipairs(clients) do
      local bac
      local click
      if v == client.focus then
        bac = beautiful.pri
        click = function()
          v.minimized = true
        end
      elseif v.urgent then
        bac = beautiful.err
      elseif v.minimized then
        bac = beautiful.dis
        click = function()
          v.minimized = false
          v = client.focus
        end
      elseif v.maximized then
        bac = beautiful.ok
        click = function()
          v.maximized = false
          v = client.focus
        end
      elseif v.fullscreen then
        bac = beautiful.warn
        click = function()
          v.fullscreen = false
          v = client.focus
        end
      else
        bac = beautiful.fg3 .. '66'
        click = function()
          v.minimized = true
        end
      end
      local widget = wibox.widget {
        forced_height = 4,
        forced_width = 55,
        shape = helpers.rrect(50),
        widget = wibox.container.background,
        buttons = {
          awful.button({}, 1, function()
            click()
          end)
        },
        bg = bac
      }
      indicators:add(widget)
    end
    return wibox.widget {
      {
        {
          indicators,
          spacing = 10,
          layout = wibox.layout.fixed.horizontal
        },
        widget = wibox.container.place,
        halign = 'center'
      },
      forced_height = 10,
      forced_width = 45,
      widget = wibox.container.background
    }
  end

  local createDockElement = function(data)
    local class = string.lower(data.class)
    local command = string.lower(data.class)
    local customIcons = {
      {
        name = "st-256color",
        convert = "xterm",
        command = "st"
      },
      {
        name = "ncmpcpppad",
        convert = "deepin-music-player",
        command = "awesome-client 'awesome.emit_signal(\"toggle::ncmpcpppad\")'"
      },
      {
        name = "pfetchpad",
        convert = "xterm",
      },
      {
        name = "feh",
        convert = "image-viewer"
      },
    }
    for _, v in pairs(customIcons) do
      if class == v.name then
        class = v.convert
        command = v.command
      end
    end
    local dockelement = wibox.widget {
      {
        {
          {
            forced_height = 50,
            forced_width = 50,
            buttons = {
              awful.button({}, 1, function()
                awful.spawn.with_shell(command)
              end)
            },
            image = getIcon(nil, class, class, false),
            clip_shape = helpers.rrect(8),
            widget = wibox.widget.imagebox,
          },
          layout = wibox.layout.fixed.horizontal
        },
        createDockIndicators(data),
        layout = wibox.layout.fixed.vertical
      },
      forced_width = 50,
      widget = wibox.container.background
    }
    return dockelement
  end



  local createDockElements = function()
    local clients = mouse.screen.selected_tag:clients()
    -- making some pinned apps
    local metadata = {
      {
        name = "nemo",
        id = 1,
        count = 0,
        clients = {},
        class = "Nemo"
      },
      {
        count = 0,
        id = 2,
        clients = {},
        name = "st-256color",
        class = "st-256color"
      },
      {
        name = "firefox",
        count = 0,
        id = 3,
        clients = {},
        class = "firefox"
      },
      {
        count = 0,
        id = 4,
        name = "ncmppcpp",
        clients = {},
        class = "ncmpcpppad"
      },
      {
        count = 0,
        id = 5,
        name = "discord",
        clients = {},
        class = "discord"
      },
      {
        count = 0,
        id = 6,
        name = "spotify",
        clients = {},
        class = "Spotify"
      },
    }
    -- end
    local classes = { "st-256color", "discord", "ncmpcpppad", "firefox", "Spotify", "Nemo" }
    local dockElements = wibox.widget { layout = wibox.layout.fixed.horizontal, spacing = 5 }
    -- generating the data
    for i, c in ipairs(clients) do
      local class = c.class
      if helpers.inTable(classes, class) then
        for u, j in pairs(metadata) do
          if metadata[u].name == class then
            table.insert(metadata[u].clients, c)
            metadata[u].count = metadata[u].count + 1
          end
        end
      else
        table.insert(classes, class)
        local toInsert = {
          count = 1,
          id = #classes + 1,
          clients = { c },
          class = class,
          name = class,
        }
        table.insert(metadata, toInsert)
      end
    end
    table.sort(metadata, function(a, b) return a.id < b.id end)
    for _, j in pairs(metadata) do
      dockElements:add(createDockElement(j))
    end
    return dockElements
  end
  local refresh = function()
    check_for_dock_hide()
    dock:setup {
      {
        createDockElements(),
        createPermaElements(),
        layout = wibox.layout.fixed.horizontal
      },
      widget = wibox.container.margin,
      margins = {
        top = 10,
        bottom = 3,
        left = 10,
        right = 10,
      },
    }
  end
  refresh()
  client.connect_signal(
    "focus",
    function()
      refresh()
    end
  )
  client.connect_signal(
    "property::minimized",
    function()
      refresh()
    end
  )
  client.connect_signal(
    "property::maximized",
    function()
      refresh()
    end
  )
  client.connect_signal(
    "manage",
    function()
      refresh()
    end
  )
  client.connect_signal(
    "unmanage",
    function()
      refresh()
    end
  )
  hotpop:connect_signal("mouse::enter", function()
    dockHide:stop()
    dock.visible = true
  end)
  hotpop:connect_signal("mouse::leave", function()
    dockHide:again()
  end)
  dock:connect_signal("mouse::enter", function()
    dockHide:stop()
    dock.visible = true
  end)
  dock:connect_signal("mouse::leave", function()
    dockHide:again()
  end)
  tag.connect_signal("property::selected", function() refresh() end)
end



screen.connect_signal('request::desktop_decoration', function(s)
  tomfoolery(s)
end)
