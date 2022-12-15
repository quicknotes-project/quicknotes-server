local cjson = require "cjson"
local sqlite3 = require "lsqlite3complete"

local us = require "./scripts/useful_stuff"

local function handlePOST(db)
    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    local sql = [[
        INSERT INTO Tags(UserID,Title)
            VALUES(?,'Tag ' || CURRENT_TIMESTAMP)]]
    local err = us.sexec(db, sql, uid)
    if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local tid = db:last_insert_rowid()
    if not tid then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local sql = [[
        SELECT TagID, Title
            FROM Tags
            WHERE TagID = ? AND UserID = ?]]
    local rows = us.srows(db, sql, tid, uid)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local row = rows()
    if not row then return ngx.HTTP_UNAUTHORIZED end

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