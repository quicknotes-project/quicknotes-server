local cjson = require "cjson"
local sqlite3 = require "lsqlite3complete"

local us = require "./scripts/useful_stuff"

local function handleGET(db)
    local sid = us.getSessionId(ngx.req.get_headers())
    if not sid then return ngx.HTTP_UNAUTHORIZED end

    local sql = [[
        SELECT u.Username, u.Fullname FROM Sessions as s
            JOIN Users as u ON s.UserID = u.UserID
            WHERE s.SessionID = ? AND
                    julianday('now', 'localtime') - julianday(s.CreatedAt) < 30]]
    local rows = us.srows(db, sql, sid)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local row = rows()
    if not row then return ngx.HTTP_UNAUTHORIZED end

    local user = {
        username = row[1],
        fullname = row[2]
    }

    ngx.say(cjson.encode(user))
    return ngx.HTTP_OK
end

local handlers = {
    GET = handleGET
}

local method = ngx.req.get_method()
local handler = handlers[method]
if not handler then ngx.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED) end

local db = sqlite3.open("./data/db.sqlite3")
local status = handler(db)
db:close()

ngx.exit(status)