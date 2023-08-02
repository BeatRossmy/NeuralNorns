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
lattice = require("lattice")


engine.name = 'Ack'
local Ack = require 'ack/lib/ack'

tabutil = require("tabutil")
JSON = include("lib/JSON")

include("lib/helper")

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

key_press = function (x,y,z)
  local i = x+y*8
    
  if z==0 then
    hold_cells[i] = nil
  else
    hold_cells[i] = {x,y-1}
  end
  
  local mean_vector = calculate_mean_vector(hold_cells)
  if mean_vector then
    tabutil.print(mean_vector)
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

on_tick = function (t)
  for ins=1,4 do
    local i = (ins-1)*8+t
    if pattern[i]>0.4 then
      if ins==3 then
        engine.kill(4-1)
      end
      engine.trig(ins-1)
    end
  end
  if latent_vector and randomness>0 then
    local dx = (math.random()-0.5)*randomness
    local dy = (math.random()-0.5)*randomness
    local x = util.clamp(latent_vector[1]+dx,0,1)
    local y = util.clamp(latent_vector[2]+dy,0,1)
    latent_vector = {x,y}
    pattern = nn:calc_from(latent_vector,"decoder")
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
  main_lattice = lattice:new{
    auto = true,
    ppqn = 96
  }
  tick = 1
  sprocket_pattern = main_lattice:new_sprocket{
    action = function(t) 
      tick = ((main_lattice.transport-1)/24)+1
      tick = util.wrap(tick,1,8)
      on_tick(tick)
      dirty = true
    end,
    division = 1/16,
    enabled = false
  }
  main_lattice:start()
  sprocket_pattern:toggle()
  
  model = JSON.get_table(_path.code.."NeuralNorns/default_models/space_model.json") 
  load_model(model)
  
  local def_samples = {
    "808-BD.wav",
    "808-SD.wav",
    "808-CH.wav",
    "808-OH.wav",
    "808-LT.wav",
    "808-MT.wav",
    "808-HT.wav",
    "808-CY.wav"
  }
  for ch=1,4 do
    Ack.add_channel_params(ch)
    params:set(ch.."_sample",_path.audio.."common/808/"..def_samples[ch])
  end
  
  clock.run(ui_update)
end

function key(n,z)
  if n==3 and z==1 then
    if main_lattice.enabled then
      main_lattice:stop()
    else
      main_lattice:start()
    end
  end
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
    if (x==tick) then l = util.linlin(0,1,5,15,val) end
    screen.level(math.floor(l))
    screen.stroke()
  end
  
  screen.level(1)
  screen.move(4,58)
  screen.text(main_lattice.enabled and "k3: pause" or "k3: play")
  
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