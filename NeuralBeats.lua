-- NeuralNorns - NeuralBeats
-- v1.0.0 @beat
-- llllllll.co/t/neuralnorns/63473
--
-- generate beats based on ML
--
-- top: pattern => triggers drums
-- mid: vector => samples pattern
-- bottom: snapshots => store vectors
--
-- turn encoder: sample random latent vector
-- short press snapshot: make snapshot
-- hold snapshot: recall snapshot while held
-- hold snapshots: interpolate snapshots

engine.name = 'Ack'
local Ack = require 'ack/lib/ack'

tabutil = require("tabutil")
JSON = include("lib/JSON")

g = grid.connect()

Sequential = include("lib/Sequential")
nn = Sequential.new()
model = nil
latent_vector = {}
interpolated_vector = {}
pattern = {}

load_model = function (m)
  nn:load_model(m)
  local shape = nn:get_shape()
  
  pattern = {}
  for i=1, shape[1]*shape[2] do
    table.insert(pattern,0)
  end
  
  latent_vector = {}
  interpolated_vector = {}
  for i=1, nn:get_units("latent") do
    table.insert(latent_vector,0)
    table.insert(interpolated_vector,0)
  end
end

tick = 0

snapshots = {nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil}

selected = {
  latent_dim = nil,
  snapshots = {}
}

count_hold = function ()
  local n = 0
  for i=1,16 do
    n = selected.snapshots[i] and (n+1) or n
  end
  return n
end

get_hold = function ()
  local hold = {}
  for i=1,16 do
    if snapshots[i] and selected.snapshots[i] then
      table.insert(hold,snapshots[i])
    end
  end
  return hold
end

mean_vector = function (vectors)
  if type(vectors) ~= "table" or #vectors==0 then return nil end
  local mean = {}
  for i=1,#vectors[1]do
    for _,v in ipairs(vectors) do
      mean[i] = mean[i] and mean[i] or 0
      mean[i] = mean[i] + v[i]
    end
    mean[i] = mean[i]/#vectors
  end
  return mean
end
 
g.key = function (x,y,z)
  local latent_left = 8-math.floor(#latent_vector/2)
  local latent_right = latent_left+#latent_vector
  -- pattern
  if (z==1 and x>=5 and x<=12 and y>=1 and y<=4) then
    local i = (4-y)*8+(x-4) -- invert
    print("set:",i)
    pattern[i] = pattern[i] >= 0.4 and 0 or 1
    pattern = nn:calc(pattern)
    latent_vector = nn:calc_to(pattern,"decoder")
    
  -- latent vector
  elseif (x>latent_left and x<=latent_right and y==6) then
    local _x = x-latent_left
    selected.latent = (z==1 and selected.latent==nil) and _x or nil
    
  -- snapshots
  elseif (x>=1 and x<=16 and y==8) then
    if (z==1) then
      selected.snapshots[x] = util.time()
    else
      local delta = util.time() - selected.snapshots[x]
      if delta<0.5 and count_hold()==1 then
        snapshots[x] = {table.unpack(latent_vector)}
      end
      selected.snapshots[x] = nil
    end
    
    -- interpolate selected snapshots
    local vectors = get_hold()
    local mean = mean_vector(vectors)
    pattern = (mean) and nn:calc_from(mean,"decoder") or nn:calc_from(latent_vector,"decoder")
  end
  
  dirty = true
end

sequencer = function ()
  tick = 0
  while true do
    clock.sync(1/4)
    tick = util.wrap(tick+1,1,8)
    
    for ins=1,4 do
      local i = (ins-1)*8+tick
      if pattern[i]>0.4 then
        if ins==3 then
          engine.kill(4-1)
        end
        engine.trig(ins-1)
      end
    end
    
    dirty = true
  end
end

ui_update = function ()
  dirty = true
  while true do
    clock.sleep(1/25)
    if dirty then
      grid_redraw()
      redraw()
    end
  end
end

function init()
  model = JSON.get_table(_path.code.."NeuralNorns/default_models/beat_model.json") 
  load_model(model)
  
  params:add_file("model", "model")
  params:set_action("model", function (path)
    model = JSON.get_table(path) 
    load_model(model)
  end)
  
  local def_samples = {
    "kick.wav",
    "snare.wav",
    "hh.wav",
    "oh.wav"
  }
  for ch=1,4 do
    Ack.add_channel_params(ch)
    params:set(ch.."_sample",_path.data.."NeuralNorns/sounds/"..def_samples[ch])
  end
  
  clock.run(sequencer)
  clock.run(ui_update)
end

function key(n,z)
  dirty = true
end

function enc(n,d)
  if n==1 then
    for i,_ in ipairs(latent_vector) do
      latent_vector[i] = math.random()
    end
    pattern = nn:calc_from(latent_vector,"decoder")
  elseif selected.latent then
    d = d*0.025
    latent_vector[selected.latent] = util.clamp(latent_vector[selected.latent]+d,0,1)
    pattern = nn:calc_from(latent_vector,"decoder")
  end
  
  dirty = true
end

function redraw()
  screen.clear()
  
  for i,val in ipairs(pattern) do
    local x = util.wrap(i,1,8)
    local y = 5-math.ceil(i/8) -- invert, so that kick is bottom row
    screen.rect(21+x*9,y*9,6,6)
    l = util.linlin(0,1,1,15,val)
    screen.level(math.floor(l))
    screen.stroke()
  end
  
  screen.update()
  
  dirty = false
end

function grid_redraw()
  g:all(0)
  
  -- pattern
  for i,val in ipairs(pattern) do
    local x = util.wrap(i,1,8)
    local y = 5-math.ceil(i/8) -- invert, so that kick is bottom row
    l = util.linlin(0,1,3,15,val)
    if x==tick then
      l = util.linlin(0,1,6,15,val)
    end
    g:led(4 + x,y,math.floor(l))
  end
  
  local latent_left = 8-math.floor(#latent_vector/2)
  local latent_right = latent_left+#latent_vector
  -- latent vector
  for i,val in ipairs(latent_vector) do
    l = util.linlin(0,1,3,15,val)
    g:led(latent_left+ i,6,math.floor(l))
  end
  
  -- snapshots
  for i=1,16 do
    l = snapshots[i] and 10 or 3
    g:led(i,8,math.floor(l))
  end
  
  g:refresh()
end

function cleanup()
  -- deinitialization
end