local cjson = require "cjson"
cjson.encode_empty_table_as_object(false)

local sqlite3 = require "lsqlite3complete"

local us = require "./scripts/useful_stuff"

local function handleGET(db)
    local query = ngx.req.get_uri_args()["content"]
    if not query then return ngx.HTTP_BAD_REQUEST end

    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    local sql = [[
        SELECT NoteID, Title, CreatedAt, ModifiedAt
            FROM Notes
            WHERE UserID = ? AND Title LIKE ?]]
    local rows = us.srows(db, sql, uid, "%" .. query .. "%")
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