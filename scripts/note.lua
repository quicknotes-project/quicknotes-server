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
    if not dataTable then return ngx.HTTP_BAD_REQUEST end

    local stmt = db:prepare(
        [[INSERT INTO Notes(UserID,CreatedAt,ModifiedAt,Content,Title)
            VALUES(?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,?,?);
        SELECT last_insert_rowid();]]
    )
    stmt:bind_values(uid, dataTable.content, dataTable.title)
    local res = stmt:step()
    -- while res ~= sqlite3.DONE or res ~= sqlite3.ERROR or res ~= sqlite3.MISUSE do
    --     res = stmt:step()
    -- end
    if res == sqlite3.ERROR then return ngx.HTTP_INTERNAL_SERVER_ERROR end
    local nid = stmt:last_insert_rowid()
    stmt:finalize()

    if not nid then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    ngx.say(nid)
    return ngx.HTTP_OK
end

local function handleGET(db)
    local noteID = tonumber(ngx.req.get_uri_args().noteID)
    if not noteID then return ngx.HTTP_BAD_REQUEST end
    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end
    local note = nil
    local err = db:exec(
        string.format(
          [[SELECT NoteID, Title,
                   CreatedAt, ModifiedAt, Content
                FROM Notes
                WHERE NoteID = "%s" AND UserID = "%s"
                LIMIT 1]],
            noteID, uid
        ),
        function (_,_,values)
            note = {
                noteID     = values[1],
                title      = values[2],
                createdAt  = values[3],
                modifiedAt = values[4],
                content    = values[5]
            }
            return 0
        end
    )
    if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end
    if not note then return ngx.HTTP_UNAUTHORIZED end

    ngx.say(cjson.encode(note))
    return ngx.HTTP_OK
end

local function handlePUT(db)
    local noteID = tonumber(ngx.req.get_uri_args().noteID)
    if not noteID then return ngx.HTTP_BAD_REQUEST end

    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    local auth = false
    local err = db:exec(
        string.format(
          [[SELECT NoteID
                FROM Notes
                WHERE NoteID = "%s" AND UserID = "%s"
                LIMIT 1]],
            noteID, uid
        ),
        function ()
            auth = true
            return 0
        end
    )
    if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end
    if not auth then return ngx.HTTP_UNAUTHORIZED end

    ngx.req.read_body()
    local dataJSON = ngx.req.get_body_data()
    if not dataJSON then return ngx.HTTP_BAD_REQUEST end

    local dataTable = cjson.decode(dataJSON)
    if not dataTable then return ngx.HTTP_BAD_REQUEST end

    local sql = [[
        UPDATE Notes
        SET ModifiedAt = CURRENT_TIMESTAMP]]

    if dataTable.title then
        sql = sql .. ', Title = "' .. dataTable.title .. '"'
    end
    if dataTable.content then
        sql = sql .. ', Content = "' .. dataTable.content .. '"'
    end
    if dataTable.tags then
        return ngx.HTTP_METHOD_NOT_IMPLEMENTED
    end

    sql = sql .. [[ WHERE NoteID = ]] .. noteID

    local err = db:exec(sql)
    if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    return ngx.HTTP_OK
end

local function handleDELETE(db)
    return ngx.HTTP_METHOD_NOT_IMPLEMENTED
end

local method = ngx.req.get_method()
local status = ngx.HTTP_METHOD_NOT_IMPLEMENTED
local db = sqlite3.open("./data/db.sqlite3")


if method == "POST" then
    status = handlePOST(db)
elseif method == "GET" then
    status = handleGET(db)
elseif method == "PUT" then
    status = handlePUT(db)
elseif method == "DELETE" then
    status = handleDELETE(db)
end

db:close()
ngx.exit(status)