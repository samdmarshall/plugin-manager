import "../src/pluginmanager.nim"

import os

var manager = createManager()

let path = getCurrentDir().joinPath("/tests/plugin/libplugin.dylib")
echo(path)
manager = manager.register(path)

for index in 0..10:
  echo($index)
  manager.fireCallback($index)
  sleep(1000)

manager = manager.remove(path)

for index in 0..10:
  echo($index)
  manager.fireCallback($index)
  sleep(1000)
