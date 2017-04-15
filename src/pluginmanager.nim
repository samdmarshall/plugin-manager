## This package relies on the ``posix`` module for dynamically loading code using ``dlopen``/``dlsym``/``dlclose``.
##
## Each plugin is a dynamic library that must exist on disk. The language it gets implemented in doesn't matter so long as the following requirements are met:
## 
## 1. contains a C function named "registerCallback" that takes a single parameter of a c-style string.
## 
## Example declaration in C:
##
## ``void registerCallback(char *name) { ... }``
##
##
## Example declaration in Nim:
##
## ``proc registerCallback(name: cstring) {.exportc.} =``
##
##
## Each plugin is responsible for implementing this method and handling any potential string that gets passed into the callback method. You are responsible for detecting when you do work based on the name of the callback string.

# ===========
# = Imports =
# ===========

import os
import posix

# =========
# = Types =
# =========

type
  CallbackProc = proc(name: cstring) {.cdecl.}
    
  Plugin = object
    path: string
    handle: pointer
    callback: CallbackProc

  InternalPluginManager = object
    modules: seq[Plugin]
  
  PluginManager* = InternalPluginManager
    ## This is the manager object that will load and keep track of active plugins, the implementation is intentionally opaque to prevent reliance on the implementation details.

# ===================
# = Private Methods =
# ===================

proc createPlugin(path: string): Plugin =
  let handle = dlopen(path, RTLD_LOCAL)
  let callback_proc_ptr = dlsym(handle, "registerCallback")
  let callback_proc = cast[CallbackProc](callback_proc_ptr)
  let plugin = Plugin(path: path, handle: handle, callback: callback_proc)
  plugin.callback("registerPlugin".cstring)
  return plugin

proc remove(plugin: Plugin) =
  plugin.callback("removePlugin".cstring)
  discard dlclose(plugin.handle)

# ==================
# = Public Methods =
# ==================

proc createManager*(): PluginManager =
  ## Initialize a new ``PluginManager`` instance.
  ##
  ## **Return Value:**
  ##
  ## **PluginManager** A new instance of the ``PluginManager`` type that has no plugins registered to it.
  ##
  return PluginManager(modules: @[])

proc register*(pm: PluginManager, path: string): PluginManager =
  ## Register a new plugin with the plugin manager
  ##
  ## **Parameters:**
  ##
  ## **pm** The instance of the plugin manager to register the plugin with.
  ##
  ## **path** The filepath to the dynamic library to be loaded as a plugin.
  ##
  ## **Return Value:**
  ##
  ## **PluginManager** An updated instance of the plugin manager.
  ##
  ## When a plugin gets loaded, it will recieve a callback with the name "``registerPlugin``".
  ##
  if not fileExists(path):
    return pm
  var plugins = pm.modules
  for plugin in pm.modules:
    if plugin.path == path:
      return pm
  let new = createPlugin(path)
  plugins.add(new)
  return PluginManager(modules: plugins)

proc remove*(pm: PluginManager, path: string): PluginManager =
  ## Removes an existing plugin from the plugin manager
  ##
  ## **Parameters:**
  ##
  ## **pm** The instance of the plugin manager that the plugin is registered with.
  ##
  ## **path** The filepath to the dynamic library to be unloaded as a plugin.
  ##
  ## **Return Value:**
  ##
  ## **PluginManager** An updated instance of the plugin manager.
  ##
  ## When a plugin gets loaded, it will recieve a callback with the name "``removePlugin``".
  ##
  var plugins = newSeq[Plugin]()
  for plugin in pm.modules:
    if plugin.path == path:
      plugin.remove()
    else:
      plugins.add(plugin)
  return PluginManager(modules: plugins)

proc fireCallback*(pm: PluginManager, name: string) =
  ## Invokes a callback on all registered plugins and passes a string describing the action. **Note:** This method is blocking, each plugin is responsible for recieving the callback string and then handling whatever work it must do asynchronously to allow the plugin manager to continue to notify other plugins of the fired callback.
  ##
  ## **Parameters:**
  ##
  ## **pm** The instance of the plugin manager.
  ##
  ## **name** The name of the callback action that you want performed.
  ##
  for plugin in pm.modules:
    plugin.callback(name.cstring)

iterator plugins*(pm: PluginManager): string =
  ## Provides a list of all plugins that are currently registered with the manager
  ##
  ## **Return Value:**
  ##
  ## **string** The full file path to the location of the plugin on disk.
  ##
  for plugin in pm.modules:
    yield plugin.path
