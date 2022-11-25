local cjson = require "cjson"
local sqlite3 = require "lsqlite3complete"

local validate = require "./scripts/validate"
local us = require "./scripts/useful_stuff"

local function handlePOST(db)
    ngx.req.read_body()
    local dataJSON = ngx.req.get_body_data()
    if not dataJSON then return ngx.HTTP_BAD_REQUEST end

    local dataTable = cjson.decode(dataJSON)
    if not dataTable or
       not validate.username(dataTable.username) or
       not validate.password(dataTable.password)
    then
        return ngx.HTTP_BAD_REQUEST
    end

    local sql = [[
        SELECT UserID, Password FROM Users
            WHERE Username = ?]]
    local rows = us.srows(db, sql, dataTable.username)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local row = rows()
    if not row then return ngx.HTTP_UNAUTHORIZED end

    if dataTable.password ~= row[2] then return ngx.HTTP_UNAUTHORIZED end

    local uid = row[1]

    local sql = [[
        INSERT INTO Sessions (UserID, CreatedAt)
            VALUES(?, CURRENT_TIMESTAMP)]]
    local err = us.sexec(db, sql, uid)
    if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local sid = db:last_insert_rowid()
    if not sid then return ngx.HTTP_INTERNAL_SERVER_ERROR end


    -- output

    local COOKIE_MAX_AGE = 86400 * 30 -- 30 days in seconds

    ngx.header['Set-Cookie'] = string.format(
        "session_id=%s; max-age=%d",
        sid,
        COOKIE_MAX_AGE
    )
    return ngx.HTTP_OK
end

local handlers = {
    POST = handlePOST
}

local method = ngx.req.get_method()
local handler = handlers[method]
if not handler then ngx.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED) end

local db = sqlite3.open("./data/db.sqlite3")
local status = handler(db)
db:close()

ngx.exit(status)