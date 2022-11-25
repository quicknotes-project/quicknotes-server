local sqlite3 = require "lsqlite3complete"

local us = require "./scripts/useful_stuff"

local sid = us.getSessionId(ngx.req.get_headers())
if not sid then ngx.exit(ngx.HTTP_UNAUTHORIZED) end

local db = sqlite3.open("./data/db.sqlite3")

local sql = [[
    DELETE FROM Sessions
        WHERE SessionID = ?]]
local err = us.sexec(db, sql, sid)

db:close()

if err ~= sqlite3.OK then ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR) end

ngx.header['Set-Cookie'] = "session_id=unset; max-age=0"
ngx.exit(ngx.HTTP_OK)