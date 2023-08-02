local Sequential = {
  new = function ()
    return {
      activations = {
        ["identity"] = function (x) return x end,
        ["sigmoid"] = function (x) return (1/(1+math.exp(-x))) end,
        ["relu"] = function (x) return (x>0 and x or 0) end,
        ["softplus"] = function (x) return log(math.exp(x) + 1) end,
        ["softsign"] = function (x) return (x / (math.abs(x) + 1)) end
        -- TODO: add rest
      },
    
      model = nil,
      
      load_model = function (self, m)
        self.model = m
      end,
      
      get_units = function (self, layer_name)
        if (self.model==nil) then return nil end
        
        for from,layer in pairs(self.model.config.layers) do
          if (layer.class_name=="Dense" and (layer.config.name==layer_name)) then
            return layer.config.units
          end
        end
      end,
      
      get_shape = function (self)
        return {self.model.width,self.model.height}
      end,
      
      calc_layer = function (self, layer, in_values, act_func)
        local out_values = {}
        for n=1, #layer.bias do
          table.insert(out_values,0)
        end
        for o=1, #out_values do
          for i=1, #in_values do
            out_values[o] = out_values[o] + in_values[i]*layer.weights[i][o];
          end
          out_values[o] = act_func(out_values[o]+layer.bias[o]);  
        end
        return out_values;
      end,
      
      calc = function (self, in_values, from, to)
        if (self.model==nil) then return nil end
        
        from = from and from or 1
        to = to and to or #self.model.config.layers
        local out_values = {}
        for index=from, to do
          local layer = self.model.config.layers[index]
          if (layer.class_name=="Dense") then
            local act_func = self.activations[layer.config.activation]
            out_values = self:calc_layer(layer,in_values, act_func)
            in_values = out_values
          end
        end
        
        return out_values
      end,
      
      calc_from = function (self, in_values, layer_name)
        if (self.model==nil) then return nil end
        
        for from,layer in pairs(self.model.config.layers) do
          if (layer.class_name=="Dense" and (found or layer.config.name==layer_name)) then
            return self:calc(in_values, from)
          end
        end
        
        return nil
      end,
      
      calc_to = function (self, in_values, layer_name)
        if (self.model==nil) then return nil end
        
        for to,layer in pairs(self.model.config.layers) do
          if (layer.class_name=="Dense" and (found or layer.config.name==layer_name)) then
            return self:calc(in_values, 1, to-1)
          end
        end
        
        return nil
      end
    }
  end,
  
  to_vector = function (matrix)
    local flat = {}
    for _,row in ipairs(matrix) do
      for _,val in ipairs(row) do
        table.insert(flat,val)
      end
    end
    return flat
  end,
  
  to_matrix = function (vector,width,order)
    local reshaped = {}
    for i,val in ipairs(vector) do
      local x = util.wrap(i,1,width)
      local y = math.ceil(i/width)
      if x==1 then
        reshaped[y] = {}
      end
      print(x,y)
      reshaped[y][x] = val
    end
    return reshaped
  end,
  
  print_vector = function (vector,width,thr)
    width = width and width or 1
    thr = thr and thr or 0.8
    local row = ""
    for i,v in ipairs(vector) do
      row = row..(v>thr and "1" or "0")
      if i%width==0 then
        print(row)
        row = ""
      end
    end
  end,
  
  print_matrix = function (matrix,thr)
    thr = thr and thr or 0.8
    local r = ""
    for _,row in ipairs(matrix) do
      for _,val in ipairs(row) do
        r = r..(val>thr and "1" or "0")
      end
      print(r)
      r = ""
    end
  end
}

return Sequential