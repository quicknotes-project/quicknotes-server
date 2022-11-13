local validate = {}

function validate.username(username)
    return
        username and
        username == username:match("[%a%d]+")
end

function validate.fullname(fullname)
    return
        fullname and
        fullname == fullname:match("[%a%s]+")
end

function validate.password(password)
    return
        password and
        password == password:match("[%a%d]+")
end

return validate