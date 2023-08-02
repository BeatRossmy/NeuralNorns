calculate_mean_vector = function (vectors)
  local vector_count = deep_count(vectors)
  if type(vectors) ~= "table" or vector_count==0 then return nil end
  local mean = {}

  for _,vector in pairs(vectors) do
    for dim,val in ipairs(vector) do
      mean[dim] = mean[dim] and mean[dim] or 0
      mean[dim] = mean[dim] + vector[dim]/vector_count
    end
  end
    
  return mean
end

deep_count = function (tab)
  local count = 0

  for _,el in pairs(tab) do
    count = count + 1
  end
  
  return count
end

function new_key_listener ()
  return {
    key_events={},
    CLICK_THRESHOLD = 0.1,
    --
    handle = function(self,x,y,z)
      local i = x + (y-1)*16
      -- FIRST PRESS
      if z==1 and not self.key_events[i] then
        self.key_events[i] = util.time()
        self.on_press(x,y)
      -- RELEASE
      elseif z==0 and self.key_events[i] then
        local duration = util.time()-self.key_events[i]
        self.key_events[i] = nil
        if duration<=self.CLICK_THRESHOLD then self.on_click(x,y) end
        self.on_release(x,y)
      end
    end,
    count_hold = function (self,count_rule)
      count_rule = count_rule and count_rule or function (x,y) return true end
      local count = 0
      for i,event in pairs(self.key_events) do
        local x = util.wrap(i,1,16)
        local y = math.ceil(i/16)
        if count_rule(x,y) then count = count + 1 end
      end
      return count
    end,
    get_hold = function (self,sel_rule)
      sel_rule = sel_rule and sel_rule or function (x,y) return true end
      local hold = {}
      for i,event in pairs(self.key_events) do
        local x = util.wrap(i,1,16)
        local y = math.ceil(i/16)
        if sel_rule(x,y) then table.insert(hold,{x,y}) end
      end
      return hold
    end,
    -- CALLBACK-FUNCTIONS
    on_press = function (x,y) print("press",x,y) end,
    on_release = function (x,y) print("release",x,y) end,
    on_click = function (x,y) print("click",x,y) end,
    on_hold = function (x,y) print("hold",x,y) end
  }
end