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
       not validate.fullname(dataTable.fullname) or
       not validate.password(dataTable.password)
    then
        return ngx.HTTP_BAD_REQUEST
    end

    local sql = [[SELECT * FROM Users WHERE Username = ?]]
    local rows = us.srows(db, sql, dataTable.username)
    if not rows then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    local row = rows()
    if row then return ngx.HTTP_CONFLICT end

    local sql = [[
        INSERT INTO Users (Username,Fullname,Password)
            VALUES(?, ?, ?)]]
    local err = us.sexec(db, sql,
        dataTable.username, dataTable.fullname, dataTable.password
    )
    if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end

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