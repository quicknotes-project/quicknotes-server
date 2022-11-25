local cjson = require "cjson"
local sqlite3 = require "lsqlite3complete"

local us = require "./scripts/useful_stuff"

local function handleGET(db)
    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    local sql = [[
        SELECT NoteID, Title, CreatedAt, ModifiedAt
            FROM Notes
            WHERE UserID = ?]]
    local rows = us.srows(db, sql, uid)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local notes = {}
    for row in rows do
        local note = {
            noteID     = row[1],
            title      = row[2],
            createdAt  = row[3],
            modifiedAt = row[4]
        }
        notes[#notes+1] = note
    end

    ngx.say(cjson.encode(notes))
    return ngx.HTTP_OK
end

if ngx.req.get_method() == "GET" then
    local db = sqlite3.open("./data/db.sqlite3")
    local status = handleGET(db)
    db:close()
    ngx.exit(status)
end

ngx.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED)