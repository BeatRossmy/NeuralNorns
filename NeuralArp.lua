-- NeuralNorns - NeuralArp
-- v1.0.0 @beat
-- llllllll.co/t/neuralnorns/63473
--
-- generate arpeggios based on ML
--
-- left: keys => play notes
-- bottom: seq => sequence notes
-- top: pattern => arpeggiates notes
-- mid: vector => samples pattern
--
-- hold keys and press step: add/remove notes
-- hold step and press keys: add/remove notes
-- hold vector: enc change lfo depth/speed


engine.name = 'PolyPerc'
hs = include('lib/halfsecond')

tabutil = require("tabutil")
musicutil = require("musicutil")

tabutil.remove = function (tab, el)
  table.remove(tab,tabutil.key(tab,el))
end

tabutil.add_or_remove = function (tab, els)
  els = type(els)=="table" and els or {els}                        
  for _,e in ipairs(els) do
    local key = tabutil.key(tab,e)
    if key then
      table.remove(tab,key)
    else
      table.insert(tab,e)
    end
  end
end

_lfos = require 'lfo'

JSON = include("lib/JSON")

g = grid.connect()

Sequential = include("lib/Sequential")
nn = Sequential.new()
model = nil

latent_vector = {}

latent_lfos = {}

arpeggio = {}

load_model = function (m)
  nn:load_model(m)
  local shape = nn:get_shape()
  
  for l=1,nn:get_units("latent") do
    table.insert(latent_vector,0)
    local speed = 3+0.7*l
    latent_lfos[l] = _lfos:add{
      shape = 'sine',
      min = 0,
      max = 1,
      depth = 0,
      mode = 'free',
      period = speed,
      action = function(scaled, raw) latent_vector[l] = scaled end
    }
    latent_lfos[l]:start()
  end
  
  for i=1, shape[1]*shape[2] do
    table.insert(arpeggio,0)
  end
end


keys = {{1,1},{2,2},{1,2},{2,3},{1,3},{1,4},{2,5},{1,5},{2,6},{1,6},{2,7},{1,7},{1,8}}
playing = {}

isKey = function (c) 
  for i,k in ipairs(keys) do 
    if k[1]==c[1] and k[2]==c[2] then
      return i
    end
  end
  return nil
end

sequence = {
  {arp=nil,notes={1,5,10,13}},
  {arp=nil,notes={1,5,10,13}},
  {arp=nil,notes={1,5,10,13}},
  {arp=nil,notes={1,5,10,13}},
  {arp=nil,notes={1,6,10,13}},
  {arp=nil,notes={1,6,10,13}},
  {arp=nil,notes={1,6,10,13}},
  {arp=nil,notes={1,6,10,13}}
}

selected = {
  step = nil,
  step_time = 0,
  latent_dim = nil,
  notes = {}
}

tick = 0

sequencer = function ()
  tick = 0
  while true do
    clock.sync(1/4)
    arpeggio = nn:calc_from(latent_vector,"decoder")
    tick = util.wrap(tick+1,1,64)
    local sub_tick = util.wrap(tick,1,8)
    
    local step = sequence[math.ceil(tick/8)]
    local arp = step.arp and step.arp or arpeggio
    
    playing = {}
    
    for y,note in ipairs(step.notes) do
      local i = (y-1)*8+sub_tick
      if arp[i]>0.2 then
        engine.hz(musicutil.note_num_to_freq(59+note))
        table.insert(playing,note)
      end
    end
    
    dirty = true
  end
end
 
g.key = function (x,y,z)
  
  local cell = {x,y}
  tabutil.print(cell)
  
  -- keys
  if isKey(cell) then
    local note = isKey(cell)
    
    if z==1 then
      engine.hz(musicutil.note_num_to_freq(59+note))
      table.insert(selected.notes,note)
      
      if selected.step then
        for _,note in ipairs(selected.notes) do
          if tabutil.contains(selected.step.notes,note) then
            tabutil.remove(selected.step.notes,note)
          else
            table.insert(selected.step.notes,note)
            table.sort(selected.step.notes)
          end
        end
      end
    else
      tabutil.remove(selected.notes,note)
    end
  
  -- pattern
  elseif (z==1 and x>=5 and x<=12 and y>=1 and y<=4) then
    local i = (4-y)*8+(x-4) -- invert
    --print("set:",i)
    --pattern[i] = pattern[i] >= 0.4 and 0 or 1
    --pattern = nn:calc(pattern)
    --latent_vector = nn:calc_to(pattern,"decoder")
    
  -- latent vector
  elseif (x>=6 and x<=11 and y==6) then
    local _x = x-5
    selected.latent_dim = (z==1 and selected.latent_dim==nil) and _x or nil
    
  -- sequence
  elseif (x>=5 and x<=12 and y==8) then
    local _x = x-4
    if (z==1) then
      selected.step = sequence[_x]
      selected.step_time = util.time()
    else
      local delta = util.time() - selected.step_time
      if delta<0.5 then
        tabutil.add_or_remove(selected.step.notes,selected.notes)
        table.sort(selected.step.notes)
      end
      selected.step = nil
    end
    
  end
  
  dirty = true
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
  for _,step in ipairs(sequence) do
    step.notes = {}
  end
  
  model = JSON.get_table(_path.code.."NeuralNorns/default_models/arp_model.json")
  load_model(model)
  
  params:add_file("model", "model")
  params:set_action("model", function (path)
    if path=="-" then return end
    model = JSON.get_table(path) 
    load_model(model)
  end)
  
  params:add_group("synth",6)
  cs_AMP = controlspec.new(0,1,'lin',0,0.5,'')
  params:add{type="control",id="amp",controlspec=cs_AMP,
    action=function(x) engine.amp(x) end}

  cs_PW = controlspec.new(0,100,'lin',0,50,'%')
  params:add{type="control",id="pw",controlspec=cs_PW,
    action=function(x) engine.pw(x/100) end}

  cs_REL = controlspec.new(0.1,3.2,'lin',0,1.2,'s')
  params:add{type="control",id="release",controlspec=cs_REL,
    action=function(x) engine.release(x) end}

  cs_CUT = controlspec.new(50,5000,'exp',0,800,'hz')
  params:add{type="control",id="cutoff",controlspec=cs_CUT,
    action=function(x) engine.cutoff(x) end}

  cs_GAIN = controlspec.new(0,4,'lin',0,1,'')
  params:add{type="control",id="gain",controlspec=cs_GAIN,
    action=function(x) engine.gain(x) end}
  
  cs_PAN = controlspec.new(-1,1, 'lin',0,0,'')
  params:add{type="control",id="pan",controlspec=cs_PAN,
    action=function(x) engine.pan(x) end}
  
  hs.init()
  
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
    arpeggio = nn:calc_from(latent_vector,"decoder")
  elseif selected.latent_dim then
    d = d*0.02
    if n==2 then
      local depth = latent_lfos[selected.latent_dim]:get("depth")
      depth = util.clamp(depth+d,0,1)
      latent_lfos[selected.latent_dim]:set("depth",depth)
    elseif n==3 then
      local period = latent_lfos[selected.latent_dim]:get("period")
      period = util.clamp(period+d,0.1,10)
      latent_lfos[selected.latent_dim]:set("period",period+d)
    end
  end
  
  dirty = true
end

function redraw()
  screen.clear()
  
  for i,val in ipairs(arpeggio) do
    local x = util.wrap(i,1,8)
    local y = 5-math.ceil(i/8) -- invert, so that kick is bottom row
    screen.rect(21+x*9,y*9,6,6)
    l = util.linlin(0,1,1,15,val)
    screen.level(math.floor(l))
    screen.stroke()
  end
  -- draw current latent vector
  
  if selected.latent_dim then
    local lfo = latent_lfos[selected.latent_dim]
    local d = lfo:get("depth")
    local s = lfo:get("period")
    
    screen.level(15)
    screen.move(0,52)
    screen.text("lfo_"..selected.latent_dim)
    screen.move(28,52)
    screen.text("d: "..d)
    screen.move(68,52)
    screen.text("s: "..s)
  end
  
  screen.update()
  
  dirty = false
end

function grid_redraw()
  g:all(0)
  
  -- pattern
  for i,val in ipairs(arpeggio) do
    local x = util.wrap(i,1,8)
    local y = 5-math.ceil(i/8) -- invert, so that kick is bottom row
    local l = util.linlin(0,1,3,15,val)
    if x==((tick-1)%8)+1 then
      l = util.linlin(0,1,6,15,val)
    end
    g:led(4 + x,y,math.floor(l))
  end
  
  -- latent vector
  for i,val in ipairs(latent_vector) do
    local l = util.linlin(0,1,3,15,val)
    g:led(5 + i,6,math.floor(l))
  end
  
  -- sequence
  for i,step in ipairs(sequence) do
    local l = #step.notes>0 and 10 or 3
    if selected.step and selected.step==step then
      l = 10
    end
    if i==math.ceil(tick/8) then
      l = 15
    end
    g:led(4+i,8,math.floor(l))
  end
  
  -- keys
  for n,k in ipairs(keys) do
    local l = 3
    local notes = selected.step and selected.step.notes or playing
    if tabutil.contains(notes,n) then
      l = selected.step and 10 or 6
    end
    if tabutil.contains(selected.notes,n) then
      l = 15
    end
    g:led(k[1],k[2],l)
  end
  
  g:refresh()
end

function cleanup()
  -- deinitialization
end