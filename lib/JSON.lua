local JSON = {
  
  to_table = function (json)
    json = json:gsub("%[","{")
    json = json:gsub("%]","}")
    json = json:gsub("\"([%a%p]+)\" ?:", "%1 =")
    return json
  end,
  
  load_json = function (file_name)
    local json_file = io.open(file_name)
    io.input(json_file)
    local json_str = io.read("*all")
    return json_to_table(json_str)
  end,
  
  get_table = function (file_name)
    local json_file = io.open(file_name)
    io.input(json_file)
    local json_str = io.read("*all")
    local lua_str = JSON.to_table(json_str)
    return load("return"..lua_str)()
  end
}

return JSON