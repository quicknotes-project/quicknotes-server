local cjson = require "cjson"
local sqlite3 = require "lsqlite3complete"

local us = require "./scripts/useful_stuff"

local function handleGET(db)
    local uid = us.getUserId(ngx.req.get_headers(), db)
    if not uid then return ngx.HTTP_UNAUTHORIZED end

    local notes = {}
    local err = db:exec(
      string.format(
          [[SELECT NoteID, Title,
                   CreatedAt, ModifiedAt
                FROM Notes
                WHERE UserID = "%s"]],
            uid
        ),
        function (_,_,values)
            local note = {
                noteID     = values[1],
                title      = values[2],
                createdAt  = values[3],
                modifiedAt = values[4]
            }
            notes[#notes+1] = note
            return 0
        end
    )
    if err ~= sqlite3.OK then return ngx.HTTP_INTERNAL_SERVER_ERROR end

    -- for _, note in pairs(notes) do
    --     note.noteID
    --     db:exec(
    --         string.format(
    --         [[SELECT t.Title FROM Notes]],
    --             uid, dataJSON
    --         ),
    --         function (_,_,values)
    --             notes[#notes+1] = note
    --             return 0
    --         end
    --     )
    -- end

    ngx.say(cjson.encode(notes))
    return ngx.HTTP_OK
end

if ngx.req.get_method() == "GET" then
    local db = sqlite3.open("data/db.sqlite3")
    local status = handleGET(db)
    db:close()
    ngx.exit(status)
end

ngx.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED)