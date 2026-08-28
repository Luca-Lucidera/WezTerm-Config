local wezterm = require 'wezterm'
local act = wezterm.action
local mux = wezterm.mux
local config = wezterm.config_builder()

-- Center the startup window on the focused screen, sized as a fraction of it.
-- An explicit size is needed: reading the natural size right after spawn races
-- with the window still being laid out.
local WINDOW_RATIO = 0.6

wezterm.on('gui-startup', function(cmd)
  local _, _, window = mux.spawn_window(cmd or {})
  local screen = wezterm.gui.screens().active
  local width = math.floor(screen.width * WINDOW_RATIO)
  local height = math.floor(screen.height * WINDOW_RATIO)
  local gui = window:gui_window()
  gui:set_inner_size(width, height)
  gui:set_position(
    screen.x + math.floor((screen.width - width) / 2),
    screen.y + math.floor((screen.height - height) / 2)
  )
end)

config.default_prog = { 'pwsh.exe', '-NoLogo' }

local PS_CWD = [[D:\wkspaces]]
local WSL_CWD = '/home/luca/code'

config.default_cwd = PS_CWD

-- Patch the auto-generated domains so future distros keep working
config.wsl_domains = wezterm.default_wsl_domains()
for _, dom in ipairs(config.wsl_domains) do
  if dom.name == 'WSL:Debian' then
    dom.default_cwd = WSL_CWD
  end
end

-- Explicit "local" domain avoids WSL leaking into Windows tabs
local LOCAL = { DomainName = 'local' }
local WSL = { DomainName = 'WSL:Debian' }

config.launch_menu = {
  {
    label = 'PowerShell 7',
    args = { 'pwsh.exe', '-NoLogo' },
    domain = LOCAL,
    cwd = PS_CWD,
  },
  {
    label = 'WSL: Debian',
    domain = WSL,
    cwd = WSL_CWD,
  },
}

config.enable_kitty_keyboard = false

config.keys = {
  { key = 'phys:1', mods = 'ALT|SHIFT', action = act.SpawnCommandInNewTab(config.launch_menu[1]) },
  { key = 'phys:2', mods = 'ALT|SHIFT', action = act.SpawnCommandInNewTab(config.launch_menu[2]) },
  { key = 'phys:E', mods = 'CTRL|SHIFT', action = act.ShowLauncher },
  { key = 'LeftArrow', mods = 'ALT', action = act.ActivateTabRelative(-1) },
  { key = 'RightArrow', mods = 'ALT', action = act.ActivateTabRelative(1) },
  { key = 'Enter', mods = 'SHIFT', action = act.SendString '\x1b\r' },
}

for i = 1, 9 do
  table.insert(config.keys, {
    key = 'phys:' .. i,
    mods = 'ALT',
    action = act.ActivateTab(i - 1),
  })
end

-- color_scheme is global, so pick it from the focused pane's domain.
-- The base16 variant is used because plain "rose-pine" sets selection_bg to its
-- own background, making mouse selections invisible.
local THEME_FOR_DOMAIN = { ['WSL:Debian'] = 'Rosé Pine (base16)' }
local FALLBACK_THEME = 'nord'
local SSH_THEME = 'Ef-Rosa'
local TITLE_FONT = wezterm.font 'CaskaydiaCove Nerd Font'

-- SSH detection: the process tree only works for local (PowerShell) panes;
-- WSL internals are invisible to WezTerm, so there the ssh() wrapper in the
-- distro's ~/.bashrc raises the IS_SSH user var instead.
local function is_ssh(proc, user_vars)
  local exe = (proc or ''):match '[^/\\]+$'
  return exe == 'ssh' or exe == 'ssh.exe' or user_vars.IS_SSH == '1'
end

wezterm.on('update-status', function(window, pane)
  local scheme
  if is_ssh(pane:get_foreground_process_name(), pane:get_user_vars()) then
    scheme = SSH_THEME
  else
    scheme = THEME_FOR_DOMAIN[pane:get_domain_name()] or FALLBACK_THEME
  end

  local tabs = window:mux_window():tabs_with_info()
  local active_tab = 1
  for _, tab in ipairs(tabs) do
    if tab.is_active then
      active_tab = tab.index + 1
      break
    end
  end
  window:set_left_status(string.format(
    '  [%d/%d] %s',
    active_tab,
    #tabs,
    pane:get_title()
  ))

  local overrides = window:get_config_overrides() or {}
  -- only write on actual change, otherwise the reload event loops
  if overrides.color_scheme ~= scheme or overrides.window_frame then
    overrides.color_scheme = scheme
    overrides.window_frame = nil
    window:set_config_overrides(overrides)
  end
end)

config.font = wezterm.font_with_fallback { 'CaskaydiaCove Nerd Font', 'Cascadia Code', 'Consolas' }
config.font_size = 12
config.freetype_load_target = 'Light'
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'HighPerformance'
config.window_decorations = 'INTEGRATED_BUTTONS | RESIZE'
config.integrated_title_buttons = { 'Hide', 'Maximize' }
config.window_frame = {
  font = TITLE_FONT,
  font_size = 12,
}
config.window_close_confirmation = 'NeverPrompt'
config.enable_tab_bar = true
config.show_tabs_in_tab_bar = false
config.show_new_tab_button_in_tab_bar = false

return config
