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
    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    ngx.req.read_body()
    local dataJSON = ngx.req.get_body_data()
    if not dataJSON then return ngx.HTTP_BAD_REQUEST end

    local dataTable = cjson.decode(dataJSON)

    if not dataTable or
       not dataTable.noteID or
       not dataTable.tagID or
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
            WHERE UserID = ? AND TagID = ?]]
    local rows = us.srows(db, sql, uid, dataTable.tagID)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end
    if not rows() then return ngx.HTTP_UNAUTHORIZED end

    -- check if tag is connected to note
    local sql = [[
        SELECT TagID
            FROM NoteTag
            WHERE TagID = ? AND NoteID = ?]]
    local rows = us.srows(db, sql, dataTable.tagID, dataTable.noteID)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end
    if not rows() then return ngx.HTTP_BAD_REQUEST end

    -- check for new tag's existence    
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

    -- update connection
    local sql = [[
        UPDATE NoteTag
            SET TagID = ?
            WHERE TagID = ? AND NoteID = ?]]
    local err = us.sexec(db, sql, tid, dataTable.tagID, dataTable.noteID)
    if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    return ngx.HTTP_OK
end

local function handleDELETE(db)
    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    ngx.req.read_body()
    local dataJSON = ngx.req.get_body_data()
    if not dataJSON then return ngx.HTTP_BAD_REQUEST end

    local dataTable = cjson.decode(dataJSON)

    if not dataTable or
       not dataTable.noteID or
       not dataTable.tagID
    then
        return ngx.HTTP_BAD_REQUEST
    end

    local sql = [[
        SELECT t.TagID
            FROM Tags AS t
            JOIN NoteTag AS nt ON nt.TagID = t.TagID
            JOIN Notes AS n ON n.NoteID = nt.NoteID
            WHERE t.TagID = ? AND n.NoteID = ? AND
                  t.UserID = ? AND n.UserID = t.UserID]]
    local rows = us.srows(db, sql, dataTable.tagID, dataTable.noteID, uid)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    if not rows() then return ngx.HTTP_UNAUTHORIZED end

    local sql = [[
        DELETE FROM NoteTag
            WHERE NoteID = ? AND TagID = ?]]
    local err = us.sexec(db, sql, dataTable.noteID, dataTable.tagID)
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