function os.capture(cmd, raw)
    local handle = assert(io.popen(cmd, 'r'))
    local output = assert(handle:read('*a'))
    
    handle:close()

    if raw then
        return output
    end

    output = string.gsub(
        string.gsub(
            string.gsub(output, '^%s+', ''),
            '%s+$',
            ''
        ),
        '[\n\r]+',
        ' '
    )
    return output
end

local uptime = os.capture("uptime")
local temp = os.capture("cat /sys/class/thermal/thermal_zone0/temp") / 1000

local status = string.format('%s,  CPU temp: %s\'', uptime, temp)

ngx.say(status)