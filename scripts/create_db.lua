local sqlite3 = require "lsqlite3complete"
local db = sqlite3.open("data/db.sqlite3")
local sql = io.open("scripts/create_db.sql", "r"):read("a")
db:exec(sql)
db:close()
ngx.say("All good")