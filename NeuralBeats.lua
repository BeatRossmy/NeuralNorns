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

lattice = require("lattice")
tabutil = require("tabutil")
JSON = include("lib/JSON")

include("lib/helper")

g = grid.connect()

key_listener = new_key_listener()

key_listener.on_press = function (x,y)
  -- snapshots
  if (x>=1 and x<=16 and y==8) then
    selected.snapshots[x] = true
    interpolate_snapshots()
  -- pattern
  elseif (x>=5 and x<=12 and y>=1 and y<=4) then
    local i = (4-y)*8+(x-4) -- invert
    print("set:",i)
    pattern[i] = pattern[i] >= 0.4 and 0 or 1
    pattern = nn:calc(pattern)
    latent_vector = nn:calc_to(pattern,"decoder")
  -- latent vector
  elseif (x>latent_left and x<=latent_right and y==6) then
    
    selected.latent = x-latent_left
    print(selected.latent)
  end
end

key_listener.on_release = function (x,y)
  --snapshots
  if (x>=1 and x<=16 and y==8) then
    selected.snapshots[x] = nil
    interpolate_snapshots()
  -- latent vector
  elseif (x>latent_left and x<=latent_right and y==6) then
    local _x = x-latent_left
    if (_x==selected.latent) then selected.latent = nil end
  end
end

key_listener.on_click = function (x,y)
  -- snapshots
  if (x>=1 and x<=16 and y==8) then
    if snapshots[x]==nil and key_listener:count_hold(function (x,y) return y==8 end)==0 then
      print("new snapshot")
      snapshots[x] = {table.unpack(latent_vector)}
    end
  end
end

interpolate_snapshots = function ()
  local hold_cells = key_listener:get_hold(function (x,y) return y==8 end)
  local vectors = {}
  for _,c in pairs(hold_cells) do table.insert(vectors,snapshots[c[1]]) end
  local mean = calculate_mean_vector(vectors)
  pattern = (mean) and nn:calc_from(mean,"decoder") or nn:calc_from({table.unpack(latent_vector)},"decoder")
end

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
 
g.key = function (x,y,z)
  key_listener:handle(x,y,z)
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
  
  model = JSON.get_table(_path.code.."NeuralNorns/default_models/beat_model.json") 
  load_model(model)
  
  latent_left = 8-math.floor(#latent_vector/2)
  latent_right = latent_left+#latent_vector
  
  params:add_file("model", "model")
  params:set_action("model", function (path)
    model = JSON.get_table(path) 
    load_model(model)
  end)
  
  local def_samples = {"808-BD.wav", "808-SD.wav", "808-CH.wav", "808-OH.wav", "808-LT.wav", "808-MT.wav", "808-HT.wav", "808-CY.wav"}
  for ch=1,4 do
    Ack.add_channel_params(ch)
    params:set(ch.."_sample",_path.audio.."common/808/"..def_samples[ch])
  end
  
  clock.run(ui_update)
end

function key(n,z)
  local hold__snapshots = key_listener:get_hold(function(x,y) return y==8 end)
  if (n==2) and z==1 then
    for _,c in pairs(hold__snapshots) do
      snapshots[c[1]] = nil
    end
  elseif n==3 and z==1 then
    if main_lattice.enabled then
      main_lattice:stop()
    else
      main_lattice:start()
    end
  end
  dirty = true
end

function enc(n,d)
  if not selected.latent then
    for i,_ in ipairs(latent_vector) do
      latent_vector[i] = math.random()
    end
  elseif selected.latent then
    d = d*0.025
    latent_vector[selected.latent] = util.clamp(latent_vector[selected.latent]+d,0,1)
  end
  
  pattern = nn:calc_from({table.unpack(latent_vector)},"decoder")
  
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
  
  -- latent vector
  for i,val in ipairs(latent_vector) do
    l = util.linlin(0,1,3,15,val)
    if i==selected.latent then l = util.linlin(0,1,10,15,val) end
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