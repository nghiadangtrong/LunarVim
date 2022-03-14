local plugin_loader = {}

local utils = require "lvim.utils"
local Log = require "lvim.core.log"
local join_paths = utils.join_paths

-- we need to reuse this outside of init()
local compile_path = join_paths(get_config_dir(), "plugin", "packer_compiled.lua")
local snapshot_path = join_paths(get_lvim_base_dir(), "snapshots")

function plugin_loader.init(opts)
  opts = opts or {}

  local install_path = opts.install_path
    or join_paths(vim.fn.stdpath "data", "site", "pack", "packer", "start", "packer.nvim")

  if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
    vim.fn.system { "git", "clone", "--depth", "1", "https://github.com/wbthomason/packer.nvim", install_path }
    vim.cmd "packadd packer.nvim"
  end

  local init_opts = {
    package_root = opts.package_root or join_paths(vim.fn.stdpath "data", "site", "pack"),
    compile_path = compile_path,
    snapshot_path = snapshot_path,
    log = { level = "warn" },
    git = {
      clone_timeout = 300,
      subcommands = {
        -- this is more efficient than what Packer is using
        fetch = "fetch --no-tags --no-recurse-submodules --update-shallow --progress",
      },
    },
    max_jobs = 50,
    display = {
      open_fn = function()
        return require("packer.util").float { border = "rounded" }
      end,
    },
  }

  local in_headless = #vim.api.nvim_list_uis() == 0
  if in_headless then
    init_opts.display = nil

    -- NOTE: `lvim.log.level` wouldn't be loaded from the user's config yet
    init_opts.log.level = "debug"

    -- this one seems to get packer stuck in headless mode
    init_opts.max_jobs = nil
  else
    vim.cmd [[autocmd User PackerComplete lua require('lvim.utils.hooks').run_on_packer_complete()]]
  end

  local status_ok, packer = pcall(require, "packer")
  if status_ok then
    packer.init(init_opts)
  end
end

-- packer expects a space separated list
local function pcall_packer_command(cmd, kwargs)
  local status_ok, msg = pcall(function()
    require("packer")[cmd](unpack(kwargs or {}))
  end)
  if not status_ok then
    Log:warn(cmd .. " failed with: " .. vim.inspect(msg))
    Log:trace(vim.inspect(vim.fn.eval "v:errmsg"))
  end
end

function plugin_loader.cache_clear()
  if vim.fn.delete(compile_path) == 0 then
    Log:debug "deleted packer_compiled.lua"
  end
end

function plugin_loader.recompile()
  plugin_loader.cache_clear()
  pcall_packer_command "compile"
  if utils.is_file(compile_path) then
    Log:debug "generated packer_compiled.lua"
  end
end

function plugin_loader.load(configurations)
  Log:debug "loading plugins configuration"
  local packer_available, packer = pcall(require, "packer")
  if not packer_available then
    Log:warn "skipping loading plugins until Packer is installed"
    return
  end
  local status_ok, _ = xpcall(function()
    packer.reset()
    packer.startup(function(use)
      for _, plugins in ipairs(configurations) do
        for _, plugin in ipairs(plugins) do
          use(plugin)
        end
      end
    end)
  end, debug.traceback)
  if not status_ok then
    Log:warn "problems detected while loading plugins' configurations"
    Log:trace(debug.traceback())
  end

  -- Colorscheme must get called after plugins are loaded or it will break new installs.
  vim.g.colors_name = lvim.colorscheme
  vim.cmd("colorscheme " .. lvim.colorscheme)
end

function plugin_loader.get_core_plugins()
  local list = {}
  local plugins = require "lvim.plugins"
  for _, item in pairs(plugins) do
    table.insert(list, item[1]:match "/(%S*)")
  end
  return list
end

function plugin_loader.sync_core_plugins(snapshot_name)
  snapshot_name = snapshot_name or "default.json"
  Log:trace(string.format("Syncing core plugins with snapshot file [%s]", snapshot_name))
  pcall_packer_command("rollback", snapshot_name)
end

return plugin_loader
