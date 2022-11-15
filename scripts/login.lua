local cjson = require "cjson"
local sqlite3 = require "lsqlite3complete"

local validate = require "./scripts/validate"

ngx.req.read_body()
local dataJSON = ngx.req.get_body_data()

if not dataJSON then ngx.exit(ngx.HTTP_BAD_REQUEST) end

local dataTable = cjson.decode(dataJSON)

if not dataTable or
   not validate.username(dataTable.username) or
   not validate.password(dataTable.password) 
then
    ngx.exit(ngx.HTTP_BAD_REQUEST)    
end

local db = sqlite3.open("./data/db.sqlite3")

local uid = nil
local err = db:exec(
    string.format(
      [[SELECT UserID, Password FROM Users
            WHERE Username = "%s"
            LIMIT 1;]],
        dataTable.username
    ),
    function (password,_,values)
        if password == values[2] then
            uid = values[1]
        end
        return 0
    end,
    dataTable.password
)

if err ~= sqlite3.OK then db:close() ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR) end
if not uid then db:close() ngx.exit(ngx.HTTP_UNAUTHORIZED) end

local sid = nil
db:exec(
    string.format(
      [[INSERT
            INTO Sessions (UserID, CreatedAt)
            VALUES("%s", CURRENT_TIMESTAMP);
        SELECT last_insert_rowid();]],
        uid
    ),
    function (_,_,values) sid = values[1] return 0 end
)

db:close()

if not sid then ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR) end



-- output

local COOKIE_MAX_AGE = 86400 * 30 -- 30 days in seconds

ngx.header['Set-Cookie'] = string.format(
    "session_id=%s; max-age=%d",
    sid,
    COOKIE_MAX_AGE
)

ngx.exit(ngx.HTTP_OK)