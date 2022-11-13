local M = {}

function M.getSessionId(headers)
    local cookies = headers["Cookie"]
    if not cookies then return nil end
    return cookies.match(cookies, "session_id%s*=%s*(%d+)")
end

function M.sidToUid(db, sid)
    local uid = nil
    db:exec(
        string.format(
        [[SELECT u.UserID FROM Sessions as s
                JOIN Users as u ON s.UserID = u.UserID
                WHERE s.SessionID = %s AND
                    julianday('now', 'localtime') - julianday(s.CreatedAt) < 30
                LIMIT 1;]],
            sid
        ),
        function (_,_,values) uid = values[1] return 0 end
    )
    return uid
end

function M.getUserId(headers, db)
    local sid = M.getSessionId(headers)
    if not sid then return nil end
    return M.sidToUid(db, sid)
end

return M