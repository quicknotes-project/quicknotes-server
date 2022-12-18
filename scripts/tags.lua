local cjson = require "cjson"
cjson.encode_empty_table_as_object(false)

local sqlite3 = require "lsqlite3complete"

local us = require "./scripts/useful_stuff"

local function handleGET(db)
    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    local sql = [[
        SELECT TagID, Title
            FROM Tags
            WHERE UserID = ?]]
    local rows = us.srows(db, sql, uid)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local tags = {}
    for row in rows do
        local tag = {
            tagID = row[1],
            title = row[2]
        }
        tags[#tags+1] = tag
    end

    ngx.say(cjson.encode(tags))
    return ngx.HTTP_OK
end

if ngx.req.get_method() == "GET" then
    local db = sqlite3.open("./data/db.sqlite3")
    local status = handleGET(db)
    db:close()
    ngx.exit(status)
end

ngx.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED)