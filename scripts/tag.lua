local cjson = require "cjson"
local sqlite3 = require "lsqlite3complete"

local us = require "./scripts/useful_stuff"

local function handlePOST(db)
    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    ngx.req.read_body()
    local dataJSON = ngx.req.get_body_data()
    if not dataJSON then return ngx.HTTP_BAD_REQUEST end

    local dataTable = cjson.decode(dataJSON)

    if not dataTable or
       not dataTable.noteID or
       not dataTable.title
    then
        return ngx.HTTP_BAD_REQUEST
    end

    -- check for note's existence
    local sql = [[
        SELECT NoteID 
            FROM Notes
            WHERE UserID = ? AND NoteID = ?]]
    local rows = us.srows(db, sql, uid, dataTable.noteID)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end
    if not rows() then return ngx.HTTP_UNAUTHORIZED end
    
    -- check for tag's existence    
    local sql = [[
        SELECT TagID
            FROM Tags
            WHERE UserID = ? AND Title = ?]]
    local rows = us.srows(db, sql, uid, dataTable.title)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local row = rows()
    local tid = nil
    if not row then
        local sql = [[
            INSERT INTO Tags(UserID,Title)
                VALUES(?,?)]]
        local err = us.sexec(db, sql, uid, dataTable.title)
        if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end
        tid = db:last_insert_rowid()
    else
        tid = row[1]
    end
    if not tid then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    -- check if tag is connected to note
    local sql = [[
        SELECT TagID
            FROM NoteTag
            WHERE TagID = ? AND NoteID = ?]]
    local rows = us.srows(db, sql, tid, dataTable.noteID)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local row = rows()
    if not row then
        local sql = [[
            INSERT INTO NoteTag(NoteID, TagID)
                VALUES(?, ?)]]
        local err = us.sexec(db, sql, dataTable.noteID, tid)
        if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end
    end

    local sql = [[
        SELECT TagID, Title
            FROM Tags
            WHERE TagID = ?]]
    local rows = us.srows(db, sql, tid)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local row = rows()
    if not row then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local tag = {
        tagID = row[1],
        title = row[2]
    }

    ngx.say(cjson.encode(tag))

    return ngx.HTTP_OK
end

local function handlePUT(db)
    local tid = tonumber(ngx.req.get_uri_args().tagID)
    if not tid then return ngx.HTTP_BAD_REQUEST end

    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    ngx.req.read_body()
    local dataJSON = ngx.req.get_body_data()
    if not dataJSON then return ngx.HTTP_BAD_REQUEST end

    local dataTable = cjson.decode(dataJSON)
    if not dataTable then return ngx.HTTP_BAD_REQUEST end

    local sql = [[
        SELECT Title
            FROM Tags
            WHERE TagID = ? AND UserID = ?]]
    local rows = us.srows(db, sql, tid, uid)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local row = rows()
    if not row then return ngx.HTTP_UNAUTHORIZED end

    local tag = {
        title = row[1]
    }

    tag.title = dataTable.title or tag.title

    local sql = [[
        UPDATE Tags
            SET Title = ?
            WHERE TagID = ?]]
    local err = us.sexec(db, sql, tag.title, tid)
    if err ~= sqlite3.OK then return ngx.HTTP_METHOD_NOT_IMPLEMENTED end

    return ngx.HTTP_OK
end

local function handleDELETE(db)
    local tid = tonumber(ngx.req.get_uri_args().tagID)
    if not tid then return ngx.HTTP_BAD_REQUEST end

    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    local sql = [[
        SELECT TagID
            FROM Tags
            WHERE TagID = ? AND UserID = ?]]
    local rows = us.srows(db, sql, tid, uid)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    if not rows() then return ngx.HTTP_UNAUTHORIZED end

    local sql = [[
        DELETE FROM Tags
            WHERE TagID = ? AND UserID = ?]]
    local err = us.sexec(db, sql, tid, uid)
    if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    return ngx.HTTP_OK
end

local handlers = {
    DELETE = handleDELETE,
    POST = handlePOST,
    PUT = handlePUT
}

local method = ngx.req.get_method()
local handler = handlers[method]
if not handler then ngx.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED) end

local db = sqlite3.open("./data/db.sqlite3")
local status = handler(db)
db:close()

ngx.exit(status)