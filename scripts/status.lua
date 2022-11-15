local uptime = io.popen("uptime"):read("a"):match("^%s*(.-)%s*$")
local temp = tonumber(io.popen("cat /sys/class/thermal/thermal_zone0/temp"):read("a"):match("^%s*(.-)%s*$")) / 1000
local status = string.format('%s\nCPU temp: %s\'C', uptime, temp)
ngx.say(status)