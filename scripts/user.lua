local cjson = require "cjson"
local sqlite3 = require "./lsqlite3complete"

local headers = ngx.req.get_headers()
local cookies = headers["Cookie"]

if not cookies then ngx.exit(ngx.HTTP_UNAUTHORIZED) end

local sid = cookies.match(cookies, "session_id%s*=%s*(%d+)")

if not sid then ngx.exit(ngx.HTTP_UNAUTHORIZED) end

local db = sqlite3.open("./data/db.sqlite3")

local response = {}
local err = db:exec(
    string.format(
      [[SELECT u.Username, u.Fullname FROM Sessions as s
            JOIN Users as u ON s.UserID = u.UserID
            WHERE s.SessionID = %s AND
                  julianday('now', 'localtime') - julianday(s.CreatedAt) < 30
            LIMIT 1;]],
        sid
    ),
    function (_,_,values)
        response.username = values[1]
        response.fullname = values[2]
        return 0
    end
)

db:close()

if err ~= sqlite3.OK then ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR) end
if not response.username or
   not response.fullname
then
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

ngx.say(cjson.encode(response))
ngx.exit(ngx.HTTP_OK)