local M = {}

function M.split(str, sep)
    -- horrible algorithm, should be rewritten
    if not sep then sep = " " end
    local res = {}
    str = str:gsub(sep, sep .. sep)
    for s in string.gmatch(sep .. str .. sep, sep .. "(.-)" .. sep) do
        if #s > 0 then
            res[#res+1] = s
        end
    end
    return res
end

function M.getSessionId(headers)
    local cookies = headers["Cookie"]
    if not cookies then return nil end
    return cookies.match(cookies, "session_id%s*=%s*(%d+)")
end

function M.sexec(db, sql, ...)
    local stmt = db:prepare(sql)
    if not stmt then return sqlite3.ERROR end;
    local err = stmt:bind_values(...)
    if err ~= sqlite3.OK then return err end
    stmt:step()
    return stmt:finalize()
end

function M.srows(db, sql, ...)
    local stmt = db:prepare(sql)
    if not stmt then return nil, sqlite3.ERROR end;
    local err = stmt:bind_values(...)
    if err ~= sqlite3.OK then return nil, err end
    local function rows() return stmt:rows()(stmt) end
    return rows, sqlite3.OK
end

function M.sidToUid(db, sid)
    local sql = [[
        SELECT u.UserID FROM Sessions as s
            JOIN Users as u ON s.UserID = u.UserID
            WHERE s.SessionID = ? AND
                julianday('now', 'localtime') - julianday(s.CreatedAt) < 30]]
    local rows = M.srows(db, sql, sid)
    if not rows then return nil end
    local row = rows()
    if not row then return nil end
    return row[1]
end

function M.getUserId(headers, db)
    local sid = M.getSessionId(headers)
    if not sid then return nil end
    return M.sidToUid(db, sid)
end

return M