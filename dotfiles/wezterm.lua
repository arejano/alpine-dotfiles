local wezterm = require 'wezterm'
local lib     = wezterm.plugin.require("https://github.com/chrisgve/lib.wezterm")
local act     = wezterm.action
local mux     = wezterm.mux

-- ─── _pde ────────────────────────────────────────────────────────────────────
package.path = package.path .. ";c:/projects/pde_salta/_pde/wezterm/?.lua"
local pde = require("commands")

-- ─── Paths ───────────────────────────────────────────────────────────────────

local paths = {
    projects    = "c:/projects/",
    note_config = "c:/Users/gustavo.arejano",
    config      = "c:/Users/arejano",
}

-- ─── Config ──────────────────────────────────────────────────────────────────

local config = wezterm.config_builder and wezterm.config_builder() or {}

-- ─── Appearance ──────────────────────────────────────────────────────────────

-- Trocar índice para mudar o tema:
-- 1=padrão  2=Gruvbox light  3=Catppuccin Mocha  4=Catppuccin Frappe
-- 5=Catppuccin Macchiato  6=Catppuccin Latte  7=Batman
local themes = {
    nil,
    "Gruvbox light, medium (base16)",
    "Catppuccin Mocha",
    "Catppuccin Frappe",
    "Catppuccin Macchiato",
    "Catppuccin Latte",
    "Batman",
}
config.color_scheme = themes[1]

config.font_size              = 10
config.default_cwd            = "c:/projects"
config.enable_tab_bar         = true
config.use_fancy_tab_bar      = false
config.tab_bar_at_bottom      = false
config.window_decorations     = "RESIZE"
config.status_update_interval = 1000
config.window_padding         = { left = 0, right = 0, top = 0, bottom = 0 }

local dark  = "#282864"
local white = "#FFFFFF"
local black = "#000000"

config.colors = {
    tab_bar = {
        background   = dark,
        active_tab   = { fg_color = white, bg_color = black },
        inactive_tab = { fg_color = white, bg_color = dark },
        new_tab      = { fg_color = white, bg_color = dark },
    }
}

-- ─── Leader ──────────────────────────────────────────────────────────────────

config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

-- ─── Key bindings ────────────────────────────────────────────────────────────

config.keys = {

    -- Foco entre painéis
    { key = 'h', mods = 'CTRL', action = act.ActivatePaneDirection 'Left' },
    { key = 'l', mods = 'CTRL', action = act.ActivatePaneDirection 'Right' },
    { key = 'k', mods = 'CTRL', action = act.ActivatePaneDirection 'Up' },
    { key = 'j', mods = 'CTRL', action = act.ActivatePaneDirection 'Down' },

    -- Redimensionar painel
    { key = 'h', mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Left',  10 } },
    { key = 'j', mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Down',  10 } },
    { key = 'k', mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Up',    10 } },
    { key = 'l', mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Right', 10 } },

    -- Navegação entre abas
    { key = '[', mods = 'CTRL',   action = act.ActivateTabRelative(-1) },
    { key = ']', mods = 'CTRL',   action = act.ActivateTabRelative(1) },
    { key = 'h', mods = 'LEADER', action = act.ActivateTabRelative(-1) },
    { key = 'l', mods = 'LEADER', action = act.ActivateTabRelative(1) },
    { key = 't', mods = 'LEADER', action = act.ShowTabNavigator },

    -- Aba direta por número
    { key = '1', mods = 'ALT', action = act.ActivateTab(0) },
    { key = '2', mods = 'ALT', action = act.ActivateTab(1) },
    { key = '3', mods = 'ALT', action = act.ActivateTab(2) },
    { key = '4', mods = 'ALT', action = act.ActivateTab(3) },
    { key = '5', mods = 'ALT', action = act.ActivateTab(4) },
    { key = '6', mods = 'ALT', action = act.ActivateTab(5) },
    { key = '7', mods = 'ALT', action = act.ActivateTab(6) },
    { key = '8', mods = 'ALT', action = act.ActivateTab(7) },
    { key = '9', mods = 'ALT', action = act.ActivateTab(8) },

    -- Workspaces
    { key = 'w', mods = 'LEADER', action = act.ShowLauncherArgs { flags = "FUZZY|WORKSPACES" } },

    -- Splits manuais
    { key = '|', mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = '%', mods = 'LEADER|SHIFT', action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },

    -- Passthrough Ctrl-A quando leader está ativo
    { key = 'a', mods = 'LEADER|CTRL', action = act.SendKey { key = 'a', mods = 'CTRL' } },

    -- _pde command palette
    {
        key = 'p', mods = 'LEADER',
        action = wezterm.action.InputSelector {
            title   = "_pde — comandos disponíveis",
            choices = pde.as_choices(),
            fuzzy   = true,
            action  = wezterm.action_callback(function(win, pane, id, label)
                if id then pde.run(id, win, pane) end
            end),
        },
    },

    -- Misc
    { key = 'f', mods = 'ALT',        action = "ToggleFullScreen" },
    { key = 'q', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = true } },

    -- Layout: Superfile (esq) + Helix (dir)  →  Ctrl+Shift+I
    {
        key = 'i', mods = 'CTRL|SHIFT',
        action = act.EmitEvent("SpawnIDE"),
    },

    -- Layout: Superfile + Helix (70%) + terminal abaixo  →  Ctrl+Shift+H
    {
        key = 'H', mods = 'CTRL|SHIFT',
        action = wezterm.action_callback(function(window, pane)
            pane:send_text("spf\r")
            wezterm.sleep_ms(100)
            pane:split { direction = "Right", size = 0.70, args = { "hx" } }
            wezterm.sleep_ms(100)
            window:perform_action(act.ActivatePaneDirection "Left", pane)
            pane:send_text("spf\r")
            pane:split { direction = "Bottom", size = 0.2 }
        end)
    },

    -- Split direito (80%)  →  Ctrl+Shift+K
    {
        key = 'k', mods = 'CTRL|SHIFT',
        action = wezterm.action_callback(function(_, pane)
            pane:split { direction = "Right", size = 0.80 }
        end),
    },

    -- Split vertical com npm run dev no estrutura-pedagogica  →  Ctrl+Shift+R
    {
        key = 'R', mods = 'CTRL|SHIFT',
        action = act.SplitVertical {
            domain = 'CurrentPaneDomain',
            cwd    = paths.projects .. "estrutura-pedagogica",
            args   = { 'npm', 'run', 'dev' },
        },
    },

    -- Executar run.bat no painel esquerdo/baixo  →  Ctrl+Shift+D
    {
        key = 'd', mods = 'CTRL|SHIFT',
        action = wezterm.action_callback(function(window, pane)
            window:perform_action(act.ActivatePaneDirection "Left", pane)
            window:perform_action(act.ActivatePaneDirection "Down", pane)
            wezterm.sleep_ms(100)
            local target = window:active_pane()
            target:send_text("run.bat\r")
            window:perform_action(act.ActivatePaneDirection "Right", target)
        end),
    },

    -- Executar zig build run no painel esquerdo/baixo  →  Ctrl+Shift+B
    {
        key = 'b', mods = 'CTRL|SHIFT',
        action = wezterm.action_callback(function(window, pane)
            window:perform_action(act.ActivatePaneDirection "Left", pane)
            window:perform_action(act.ActivatePaneDirection "Down", pane)
            wezterm.sleep_ms(100)
            local target = window:active_pane()
            target:send_text("cls\r")
            target:send_text("zig build run\r")
            window:perform_action(act.ActivatePaneDirection "Right", target)
        end),
    },
}

-- ─── Event: SpawnIDE ─────────────────────────────────────────────────────────

wezterm.on("SpawnIDE", function(window, _)
    local left = window:active_pane():split {
        direction = "Left",
        size      = 60.0 / window:get_dimensions().pixel_width,
        args      = { "spf" },
    }
    local right = left:split {
        direction = "Right",
        size      = 1.0,
        args      = { "hx" },
    }
    -- Persiste o pane_id do Helix para integração futura com Superfile
    local f = io.open(os.getenv("HOME") .. "/.helix_pane_id", "w")
    if f then
        f:write(tostring(right:pane_id()))
        f:close()
    end
end)

-- ─── Event: gui-startup ──────────────────────────────────────────────────────

wezterm.on('gui-startup', function()
    local tab_dbeaver, _, window = mux.spawn_window {
        cwd = 'C:/Users/gustavo.arejano/AppData/Roaming/DBeaverData/workspace6/General/Scripts',
    }
    window:gui_window():maximize()
    tab_dbeaver:set_title("code")

    local startup_tabs = {
        { title = "code",     cwd = "c:/projects" },
        { title = "config",   cwd = "c:/Users/arejano" },
        { title = "doc-ped",  cwd = paths.projects .. "documentacao-pedagogica/frontend" },
        { title = "portal",   cwd = paths.projects .. "portal-atlas" },
        { title = "estr-ped", cwd = paths.projects .. "estrutura-pedagogica/frontend" },
        { title = "claude",   cwd = paths.projects .. "pde_salta" },
    }

    for _, t in ipairs(startup_tabs) do
        local tab = window:spawn_tab { cwd = t.cwd }
        tab:set_title(t.title)
    end
end)

-- ─── Event: update-status ────────────────────────────────────────────────────

local function update_left_status(window)
    local mode  = window:leader_is_active() and "L" or "N"
    window:set_left_status(wezterm.format({
        { Background = { Color = dark } },
        { Foreground = { Color = white } },
        { Text = " " .. mode .. " " },
    }))
end

local function update_right_status(window, pane)
    local cwd_text = "none"
    local cwd = window:active_pane():get_current_working_dir()
    if cwd then
        cwd_text = tostring(cwd):gsub("file:///", "")
    end

    local process_text = "."
    local process_name = pane:get_foreground_process_name()
    if process_name then
        process_text = tostring(process_name):gsub(".*\\", "")
    end

    window:set_right_status(wezterm.format({
        { Background = { Color = dark } },
        { Foreground = { Color = white } },
        { Text = " " .. wezterm.nerdfonts.md_code_brackets .. " " .. process_text .. " " },
        { Background = { Color = dark } },
        { Text = " " .. wezterm.nerdfonts.cod_folder_opened .. " " .. cwd_text },
        { Background = { Color = dark } },
        { Text = " " .. wezterm.nerdfonts.cod_calendar .. "  " .. wezterm.strftime("%d.%m.%Y") .. " " },
    }))
end

wezterm.on("update-status", function(window, pane)
    update_left_status(window)
    update_right_status(window, pane)
end)

-- ─── Launch menu ─────────────────────────────────────────────────────────────

config.launch_menu = {
    { label = "Helix", args = { "hx" } },
}

-- ─────────────────────────────────────────────────────────────────────────────

return config
