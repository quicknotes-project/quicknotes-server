local sqlite3 = require "lsqlite3complete"

local us = require "./scripts/useful_stuff"

local sid = us.getSessionId(ngx.req.get_headers())

local db = sqlite3.open("./data/db.sqlite3")

db:exec(
    string.format(
      [[DELETE FROM Sessions
            WHERE SessionID = "%s"]],
        sid
    )
)

db:close()

ngx.header['Set-Cookie'] = "session_id=unset; max-age=0"

ngx.exit(ngx.HTTP_OK)
