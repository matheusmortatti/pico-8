------------------------------------
-- friendly
------------------------------------

-------------------------------
-- entity: fireplace
-------------------------------

fireplace=entity:extend(
  {
    fr=2,ff=2,
    draw_order=2,
    lr=24
  }
)

fireplace:spawns_from(98)

function fireplace:init()
  add(lightpoints, self)
end

function fireplace:destroy()
  del(lightpoints, self)
end

function fireplace:update()
  if (self.t%10==0)self.lr=rnd(9)+16
  add_explosion(self.pos,1,2,2,-3,-1,7,9,0)
end

-------------------------------
-- entity: dialogue box
-------------------------------
dialogue_box=entity:extend({
    is_talking=false,
    cursor=0,
    tspd=2,
    base_offset = 6,
    offset = 0,
    line_size=0,
    index=1,
    draw_order=7
})

function dialogue_box:update()
    if (not self.running or self.cursor >= #self.lines[self.index]) return

    if self.t%self.tspd == 0 then
        self.cursor += 1
        self.current_line_size+=1
        
        self.line_size = max(self.current_line_size, self.line_size)
        if sub(self.lines[self.index], self.cursor, self.cursor) == '\n' then
          self.offset += 1
          self.current_line_size=0
        end
    end
end

function dialogue_box:stop()
  self.running=false
end

function dialogue_box:start()
  self.running=true
  self.index=1
  self.cursor=0 self.offset=0 self.line_size=0 self.current_line_size=0
end

function dialogue_box:next()
  if (not self.running)self:start() return
  
  -- if we are not at the end of the line, do nothing
  if (self.cursor != 0 and self.cursor < #self.lines[self.index]) return

  self.index+=1
  self.cursor=0 self.offset=0 self.line_size=0 self.current_line_size=0
  if (self.index>#self.lines) self:stop()
end

function dialogue_box:render()
  if (not self.running) return
  local x,y=self.pos.x-10,self.pos.y-8-self.base_offset*self.offset
  if self.cursor ~= 0 then 
    rectfill(x-1, y-2, x+4*self.line_size, y+6*(self.offset+1), 0)
    rect(x-2,y-2,x+4*self.line_size+1, y+6*(self.offset+1)+1, 7)
  end
  print(sub(self.lines[self.index], 0, self.cursor), x, y, 7)
end

-------------------------------
-- entity: old man
-------------------------------

old_man=dynamic:extend({
 collides_with={"player"},
 tags={"old_man"}, dir=v(1,0),
 hitbox=box(-8,-8,16,16),
 draw_order=3,
 ssize=3,
 inv_sp=30,
 c_tile=false
})

old_man:spawns_from(128,129,130,131,132,133,134)

function old_man:init()
    self.toff=rnd(30) 
    self.dialog=e_add(
        dialogue_box({
            lines=lines[self.sprite] and lines[self.sprite] or {''},
            pos=self.pos
        }))
end

function old_man:end_collision()
    self.dialog:stop()
    self.p_near=false
end

function old_man:collide(e)
    if (btnp(5))self.dialog:next()
    self.p_near=true
end

function old_man:render()
 local s=0
 s=s+flr(self.ssize*((self.t+self.toff)%self.inv_sp)/self.inv_sp)
 spr(s,self.pos.x, self.pos.y)
 if self.p_near and not self.dialog.running then
    print("x",self.pos.x+3,self.pos.y-6,7)
 end
end

-------------------------------
-- entity: light system
-------------------------------

lightpoints = {}

light_system=entity:extend({
 draw_order=7,
 rects={},
 pt={0b0.1,0b0101101001011010.1,0b1111111111111111.1}
})

light_system:spawns_from(48)

function light_system:update()
  for i=0,15 do
    for j=0,15 do
      local ll=1
      for e in all(lightpoints) do
        local r=e.lr
        if r then
          local dist = v(
            abs(e.pos.x-(cm.pos.x+i*8)),
            abs(e.pos.y-(cm.pos.y+j*8))
          ):len()

          if dist < r then
            ll=3
          elseif dist < (r+8) and ll<2 then
            ll=2
          end
        end
      end
      self.rects[i*16+j] = {cm.pos.x+i*8,cm.pos.y+j*8,ll}
    end
  end
end

function light_system:render()
  for i=1,16*16 do
    local v=self.rects[i-1]
    local x,y,ll=v[1],v[2],v[3]
    fillp(self.pt[ll])
    rectfill(x,y,x+8,y+8,0)
    fillp()
  end
end

-------------------------------
-- entity: pedestal
-------------------------------

pedestal=entity:extend({
  tags={"pedestal"},
  draw_order=1,
  persistent=true
})

pedestal:spawns_from(78)

function pedestal:init()
  e_add(key({
     pos=self.pos + v(4,-10),
    }))
end

-------------------------------
-- entity: key
-------------------------------

key=dynamic:extend({
 collides_with={"player", "gate","key"},
 tags={"key"}, dir=v(1,0),
 hitbox=box(0,0,8,8),
 draw_order=2,
 amp=5,
 scl=0.01,
 sprite=13,
 spd=0.05,
 c_tile=false,
 persistent=true
})

function key:init()
  self:become("idle")
  self.si=flr(self.pos.x/128)+8*flr(self.pos.y/128)
  if band(dget(1),shl(1,self.si))!=0 then
    self.done=true
  end
end

function key:idle()
  self.pos += v(0, 0.5*sin(self.t/70+0.5))
end

function key:follow()
  local g = e_find_tag("gate")[1]
  if (g and is_in_level(self, g)) self.p=g

  local v=self.p.pos-self.pos
  self.dir=v:norm()
  self.vel=self.dir*(v:len()-4)*self.spd
end

function key:collide(e)
  if (self.state=="idle") self.p=e self:become("follow")
  if e:is_a("gate") then
   self.done=true
   dset(1, bor(dget(1),shl(1,self.si)))
   add_explosion(self.pos,2,8,8)
  elseif e:is_a("key") then
    return c_push_out
  end
end

-------------------------------
-- entity: door
-------------------------------

door=entity:extend({
  hitbox=box(0,0,16,16),
  collides_with={"player","enemy"},
  tags={"door"},
  draw_order=1,
  persistent=true
})

door:spawns_from(12)

function door:update()
  if self.t==0 then
    self.btn=e_find_tag("button")
    for b in all(self.btn) do
      if (not is_in_level(self,b)) del(self.btn,b)
    end
  end

  self.p=0
  for b in all(self.btn) do
    if (b.state=="pressed") self.p+=1
  end

  if (self.p==#self.btn) self:become("dead")
end

function door:dead()
  if (self.t==60) self.done=true
  if self.t%10 then
    add_explosion(self.pos,2,10,10,-2,-2,nil,nil,1)
  end
end

function door:render()
  spr(11, self.pos.x, self.pos.y, 2, 2)

  local x,y=self.pos.x+6,self.pos.y+6
  rectfill(x-1,y-1,x+4,y+5,0)
  print(tostr(#self.btn-self.p), x,y,12)
end

function door:collide(e) return c_push_out end

-------------------------------
-- entity: gate
-------------------------------

gate=door:extend({
  hitbox=box(0,0,16,16),
  collides_with={"key", "player"},
  tags={"gate"},
  kspr=13,
  kcount=3,
  off=v(8,8),
  persistent=true
})

gate:spawns_from(11)

function gate:init() 
  self.kcount=dget(0)
end

function gate:update()
  if(self.kcount<=0) self:become("dead")
end

function gate:render()
  spr(self.sprite, self.pos.x, self.pos.y, 2, 2)

  local off=-1
  for i=1,self.kcount do
    spr(self.kspr, self.pos.x+off, self.pos.y+6)
    off+=5
  end
end

function gate:collide(e)
  if e:is_a("key") then
    self.kcount-=1
    dset(0, self.kcount)
    return
  end
  
  return c_push_out
end

-------------------------------
-- entity: button
-------------------------------

button=entity:extend({
  hitbox=box(0,0,8,8),
  collides_with={"player","enemy"},
  tags={"button"},
  draw_order=1,
  persistent=true
})

button:spawns_from(61)

function button:pressed()
  if self.t==0 then
    add_explosion(self.pos+v(0,6),3,8,2)
  end
  self.sprite=62
end

function button:released()
  self.sprite=61
end

function button:collide(e)
  self:become("pressed")
end

function button:end_collision(e)
  self:become("released")
end

-------------------------------
-- entity: chimney
-------------------------------

chimney=entity:extend({})

chimney:spawns_from(76)

function chimney:update()
  if self.t%3==0 then
    p_add(smoke({
          pos=v(self.pos.x+3+rnd(2),self.pos.y-1),
          c=7,r=1+rnd(1),v=0.15
        }))
  end
end

-------------------------------
-- entity: sword upgrade
-------------------------------

upgrade=entity:extend({
  collides_with={"player"},
  hitbox=box(0,0,8,8),
  type="sword"
})

upgrade:spawns_from(4,51)

function upgrade:init()
  if (self.sprite==51) self.type="movement" self.ssize=2 self.svel=0.05
  self.pos+=v(4,4)
end

function upgrade:update()
  self.pos += v(0, 0.5*sin(self.t/40+0.5))
  if self.t%3==0 and self.type=="sword" then
    p_add(smoke({
          pos=v(self.pos.x+rnd(8),self.pos.y+8),
          c=12,r=1+rnd(1),v=0.15
        }))
  end
end

function upgrade:collide(e)
  local c=12
  if self.type=="sword" then
    dset(2,1)
    e.sword_upgrade=true
  else
    dset(3,1)
    e:upgrade_movement()
    c=9
  end
  add_explosion(self.pos,10,8,0,0,-8,c,7,5)
  self.done=true
end