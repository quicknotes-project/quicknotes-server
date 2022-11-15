local cjson = require "cjson"
local sqlite3 = require "./lsqlite3complete"

local validate = require "./scripts/validate"

ngx.req.read_body()
local dataJSON = ngx.req.get_body_data()

if not dataJSON then ngx.exit(ngx.HTTP_BAD_REQUEST) end

local dataTable = cjson.decode(dataJSON)

if not dataTable or
   not validate.username(dataTable.username) or
   not validate.fullname(dataTable.fullname) or
   not validate.password(dataTable.password) 
then
    ngx.exit(ngx.HTTP_BAD_REQUEST)    
end

local db = sqlite3.open("data/db.sqlite3")

local err = db:exec(
    string.format(
        [[SELECT * FROM Users WHERE Username = "%s"]],
        dataTable.username
    ),
    function () return 1 end
)

if err == sqlite3.ABORT then db:close() ngx.exit(ngx.HTTP_CONFLICT) end
if err ~= sqlite3.OK then db:close() ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR) end

err = db:exec(
    string.format(
      [[INSERT INTO Users (Username,Fullname,Password)
               VALUES("%s","%s","%s")]],
        dataTable.username, dataTable.fullname, dataTable.password
    )
)

db:close()

if err ~= sqlite3.OK then ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR) end
ngx.exit(ngx.HTTP_OK)