-- NeuralNorns - NeuralSpace
-- v1.0.0 @beat
-- llllllll.co/t/neuralnorns/63473
--
-- generate beats based on ML
--
-- top: latent space
-- 12/1-16/1: pattern recoder
--
-- press latent space => sample pattern

local pattern_time = require 'pattern_time'



engine.name = 'Ack'
local Ack = require 'ack/lib/ack'

tabutil = require("tabutil")
JSON = include("lib/JSON")

g = grid.connect()

hold_cells = {}

randomness = 0;

Sequential = include("lib/Sequential")
nn = Sequential.new()
model = nil
latent_vector = nil
pattern = {}

load_model = function (m)
  nn:load_model(m)
  local shape = nn:get_shape()
  
  pattern = {}
  for i=1, shape[1]*shape[2] do
    table.insert(pattern,0)
  end
  
  latent_vector = nil
end

tick = 0

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

key_press = function (x,y,z)
  local i = x+y*8
    
  if z==0 then
    hold_cells[i] = nil
  else
    hold_cells[i] = {x,y-1}
  end
  
  local mean_vector = nil
  local cell_count = 0
  for _,c in pairs(hold_cells) do
    cell_count = cell_count + 1
    mean_vector = mean_vector and {mean_vector[1]+c[1],mean_vector[2]+c[2]} or {c[1],c[2]}
  end
  if cell_count>0 then
    mean_vector = {mean_vector[1]/cell_count,mean_vector[2]/cell_count}
  end
  
  if mean_vector then
    latent_vector = {mean_vector[1]/16,mean_vector[2]/7}
    pattern = nn:calc_from(latent_vector,"decoder")
  else
    local shape = nn:get_shape()
    latent_vector = nil
    pattern = {}
    for i=1, shape[1]*shape[2] do
      table.insert(pattern,0)
    end
  end
end

exec_key_press = function (d)
  key_press(d[1],d[2],d[3])
end

g.key = function (x,y,z)
  
  if z==1 and y==1 and x>12 then
    if active_pattern then
      if active_pattern.rec==1 then
        active_pattern:rec_stop()
      elseif active_pattern.play==1 then
        active_pattern:stop()
        active_pattern=nil
        return
      end
    end
    active_pattern = event_pattern[x-12]
    
    if active_pattern.count==0 then active_pattern:rec_start()
    else active_pattern:start() end
    
  elseif y>1 then
    
    key_press(x,y,z)
    if active_pattern then active_pattern:watch({x,y,z}) end
  end
  
  dirty = true
end

sequencer = function ()
  tick = 0
  while true do
    clock.sync(1/4)
    tick = util.wrap(tick+1,1,8)
    
    if latent_vector then
      latent_vector[1] = util.clamp(latent_vector[1] + (math.random()-0.5)*randomness,0,1)
      latent_vector[2] = util.clamp(latent_vector[2] + (math.random()-0.5)*randomness,0,1)
      pattern = nn:calc_from(latent_vector,"decoder")
    end
    
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




------ patterns
event_pattern = {}
for i=1,4 do
  event_pattern[i] = pattern_time.new()
  event_pattern[i].process = exec_key_press
end
active_pattern = nil






function init()
  model = JSON.get_table(_path.code.."NeuralNorns/default_models/space_model.json") 
  load_model(model)
  
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
  randomness = util.clamp(randomness+d*0.001,0,0.2)
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
  
  for i,p in ipairs(event_pattern) do
    if p.rec==1 then g:led(12+i,1,10)
    elseif p.play==1 then g:led(12+i,1,15)
    else g:led(12+i,1,p.count==0 and 3 or 5) end
  end
  
  if latent_vector then
    g:led(math.floor(latent_vector[1]*16),1 + math.floor(latent_vector[2]*7),5)
  end
  
  for _,cell in pairs(hold_cells) do
    g:led(cell[1],1 + cell[2],10)
  end
  
  g:refresh()
end

function cleanup()
  -- deinitialization
end