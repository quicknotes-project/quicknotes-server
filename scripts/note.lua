local cjson = require "cjson"
local sqlite3 = require "lsqlite3complete"

local us = require "./scripts/useful_stuff"

local function handlePOST(db)
    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    local sql = [[
        INSERT INTO Notes(UserID,CreatedAt,ModifiedAt,Title, Content)
            VALUES(?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,'Note ' || CURRENT_TIMESTAMP,'')]]
    local err = us.sexec(db, sql, uid)
    if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local nid = db:last_insert_rowid()
    if not nid then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local sql = [[
        SELECT NoteID, Title, CreatedAt, ModifiedAt, Content
            FROM Notes
            WHERE NoteID = ? AND UserID = ?]]
    local rows = us.srows(db, sql, nid, uid)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local row = rows()
    if not row then return ngx.HTTP_UNAUTHORIZED end

    local note = {
        noteID     = row[1],
        title      = row[2],
        createdAt  = row[3],
        modifiedAt = row[4],
        content    = row[5]
    }

    ngx.say(cjson.encode(note))

    return ngx.HTTP_OK
end

local function handleGET(db)
    local nid = tonumber(ngx.req.get_uri_args().noteID)
    if not nid then return ngx.HTTP_BAD_REQUEST end

    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    local sql = [[
        SELECT NoteID, Title, CreatedAt, ModifiedAt, Content
            FROM Notes
            WHERE NoteID = ? AND UserID = ?]]
    local rows = us.srows(db, sql, nid, uid)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local row = rows()
    if not row then return ngx.HTTP_UNAUTHORIZED end

    local note = {
        noteID     = row[1],
        title      = row[2],
        createdAt  = row[3],
        modifiedAt = row[4],
        content    = row[5]
    }

    local sql = [[
        SELECT t.TagID, t.Title
            FROM Tags as t
            JOIN NoteTag as nt ON nt.TagID = t.TagID
            WHERE nt.NoteID = ? AND t.UserID = ?]]
    local rows = us.srows(db, sql, nid, uid)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    note.tags = {}
    for row in rows do
        note.tags[#note.tags+1] = {
            tagID = row[1],
            title = row[2],
        }
    end

    ngx.say(cjson.encode(note))
    return ngx.HTTP_OK
end

local function handlePUT(db)
    local nid = tonumber(ngx.req.get_uri_args().noteID)
    if not nid then return ngx.HTTP_BAD_REQUEST end

    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    ngx.req.read_body()
    local dataJSON = ngx.req.get_body_data()
    if not dataJSON then return ngx.HTTP_BAD_REQUEST end

    local dataTable = cjson.decode(dataJSON)
    if not dataTable then return ngx.HTTP_BAD_REQUEST end

    local sql = [[
        SELECT Title, Content
            FROM Notes
            WHERE NoteID = ? AND UserID = ?]]
    local rows = us.srows(db, sql, nid, uid)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local row = rows()
    if not row then return ngx.HTTP_UNAUTHORIZED end

    local note = {
        title   = row[1],
        content = row[2]
    }

    note.title   = dataTable.title   or note.title
    note.content = dataTable.content or note.content

    local sql = [[
        UPDATE Notes
        SET Title = ?, Content = ?, ModifiedAt = CURRENT_TIMESTAMP
        WHERE NoteID = ?]]
    local err = us.sexec(db, sql, note.title, note.content, nid)
    if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    return ngx.HTTP_OK
end

local function handleDELETE(db)
    local nid = tonumber(ngx.req.get_uri_args().noteID)
    if not nid then return ngx.HTTP_BAD_REQUEST end

    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    local sql = [[
        SELECT NoteID
            FROM Notes
            WHERE NoteID = ? AND UserID = ?]]
    local rows = us.srows(db, sql, nid, uid)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    if not rows() then return ngx.HTTP_UNAUTHORIZED end

    local sql = [[
        DELETE FROM Notes
            WHERE NoteID = ? AND UserID = ?]]
    local err = us.sexec(db, sql, nid, uid)
    if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    return ngx.HTTP_OK
end

local handlers = {
    DELETE = handleDELETE,
    POST = handlePOST,
    GET = handleGET,
    PUT = handlePUT
}

local method = ngx.req.get_method()
local handler = handlers[method]
if not handler then ngx.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED) end

local db = sqlite3.open("./data/db.sqlite3")
local status = handler(db)
db:close()

ngx.exit(status)