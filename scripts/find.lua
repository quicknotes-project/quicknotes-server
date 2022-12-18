local cjson = require "cjson"
cjson.encode_empty_table_as_object(false)

local sqlite3 = require "lsqlite3complete"

local us = require "./scripts/useful_stuff"

local function handleGET(db)
    local title = ngx.req.get_uri_args().title
    local tags  = ngx.req.get_uri_args().tags
    if (not title or #title == 0) and
       (not tags  or #tags == 0)
    then
        return ngx.HTTP_BAD_REQUEST
    end

    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    local tags = us.split(tags, ",")
    local rows = nil
    if not tags or #tags == 0 then -- only title
        local sql = [[
            SELECT NoteID, Title, CreatedAt, ModifiedAt
                FROM Notes
                WHERE UserID = ? AND Title LIKE ?]]
        rows = us.srows(db, sql, uid, "%" .. title .. "%")
    elseif not title or #title == 0 then -- only tags
        local subsql = [[
            SELECT DISTINCT nt.NoteID FROM NoteTag AS nt
                JOIN Tags AS t ON t.TagID = nt.TagID
                WHERE t.Title = ?]]

        local subsqlTable = {}
        for _ = 1,#tags do subsqlTable[#subsqlTable+1] = subsql end

        local sql = string.format([[
            SELECT NoteID, Title, CreatedAt, ModifiedAt
                FROM Notes
                WHERE UserID = ? AND NoteID IN (%s)]],
            table.concat(subsqlTable, " INTERSECT ")
        )
        rows = us.srows(db, sql, uid, unpack(tags))
    else -- title and tags
        local subsql = [[
            SELECT DISTINCT nt.NoteID FROM NoteTag AS nt
                JOIN Tags AS t ON t.TagID = nt.TagID
                WHERE t.Title = ?]]

        local subsqlTable = {}
        for _ = 1,#tags do subsqlTable[#subsqlTable+1] = subsql end

        local sql = string.format([[
            SELECT NoteID, Title, CreatedAt, ModifiedAt
                FROM Notes
                WHERE UserID = ? AND Title LIKE ? AND NoteID IN (%s)]],
            table.concat(subsqlTable, " INTERSECT ")
        )
        rows = us.srows(db, sql, uid, "%" .. title .. "%", unpack(tags))
    end
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