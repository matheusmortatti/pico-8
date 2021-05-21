------------------------------------
-- friendly
------------------------------------

------------------------------------
-- e_player
------------------------------------

player=dynamic:extend({
 state="walking", vel=v(0,0),
 collides_with={"slowdown"},
 tags={"player"}, dir=v(1,0),
 hitbox=box(2,3,6,8),
 sprite=0,
 draw_order=3,
 fric=0.5,
 inv_t=30,
 ht=0,
 hit=false,
 dmg=1,
 has_swrd=false,
 basevel=1,
 lr=32,
 persistent=true
})

player:spawns_from(32)

function player:init()
 self.last_dir=v(1,0)
 add(lightpoints, self)
end

function player:destroy()
 del(lightpoints, self)
end

function player:update()
 self.ht+=1
 if self.ht > self.inv_t then
  self.hit=false
  self.ht=0
 end

  if global_timer==0 and self.state!="dead" then
    self:become("dead") self.sprite=37
  end
end

function player:walking()
 self.dir=v(0,0)

 if self.hit and self.ht<self.inv_t/2 then self:set_vel() return end

 if btn(0) then self.dir.x = -1 end
 if btn(1) then self.dir.x =  1 end
 if btn(2) then self.dir.y = -1 end
 if btn(3) then self.dir.y =  1 end

 self:set_vel()

 -- correct diagonal movement
 if self.vel.x ~= 0 and self.vel.y ~= 0 then
  self.vel/=1.4
 end

 if (self.dir~=v(0,0)) self.last_dir=v(self.dir.x,self.dir.y)

 if btnp(4) then 
  self:become("attacking")
 end
 self.maxvel = self.basevel
end

function player:attacking()
 if not self.attk then
  local dir=self.last_dir.x~=0 and v(self.last_dir.x,0) or v(0, self.last_dir.y)
  self.attk=sword_attack(
    {
      pos=self.pos+dir*8,
      facing=dir,
      upg=self.has_swrd
    }
  )
  self.attk.dmg=self.dmg
  e_add(self.attk)    
 end

 self.vel=v(0,0)
 if self.attk.done then 
  self.attk=nil 
  self:become("walking")
 end
end

function player:dead()
  self.vel=v(0,0)
  if (self.t>30*5) run(stat(6))
end

function player:render()
  if (self.hit and self.t%3==0) return

  local st,flip,spd="idle",false,0.1

  if self.state=="dead" then
    self.sprite+=spd
    self.sprite=min(self.sprite,40)
  else
    st=self.vel==v(0,0) and "idle" or "walking"
    flip=false
    spd=st=="idle" and 0 or 0.15
    self.sprite=st=="idle" and 32 or 33
    self.sprite+=flr(self.t*spd)%4
  end

  if self.last_dir.x<0 then
    flip=true
  end

 spr(self.sprite, self.pos.x, self.pos.y, 1, 1, flip)
end

function player:damage()
 if not self.hit then
  p_add(ptext({
    pos=v(self.pos.x-10,self.pos.y),
    txt="-1"
  }))
  self.ht=0
  self.hit=true

  return true
 end  
end

-- function player:collide(e)
--  if e:is_a("slowdown") then
--   self.maxvel=self.basevel/2
--  end
-- end

-------------------------------
-- entity: sword_attack
-------------------------------

sword_attack=entity:extend(
{
 lifetime=10,
 hitbox=box(0,0,8,8),
 tags={"attack"},
 collides_with={"enemy"},
 facing=v(1,0),
 dmg=1,
 sprite=3,
 draw_order=5
})

function sword_attack:init()
 if self.upg then
  for i=1,4 do
   e_add(smoke({
    pos=v(self.pos.x+rnd(8),self.pos.y+rnd(8)),
    c=rnd(1)<0.7 and 12 or 7,
   }))
  end
 end
end

function sword_attack:update()
 self.flipx=self.facing.x==-1
 self.flipy=self.facing.y==1

 if self.facing.x ~= 0 then self.sprite=3 else self.sprite=4 end
 if self.t > self.lifetime then self.done=true end

 self.hitbox=nil
end

function sword_attack:render()  
 spr(self.sprite, self.pos.x, self.pos.y, 1, 1, self.flipx, self.flipy)

 local nf=v(abs(self.facing.y),abs(self.facing.x))
 local off=v(abs(self.facing.x),abs(self.facing.y))*4+v(4,4)
 local pos=self.pos+nf*2
 if self.t >= 3*self.lifetime/4 then
  self:draw_dit((self.lifetime-self.t),(self.lifetime/4))    
 end
end

function sword_attack:collide(e)
 if e:is_a("enemy") and not e.hit then
  e:damage(self.dmg)
  local allowed_dirs={
   v(-1,0)==self.facing,
   v(1,0)==self.facing,
   v(0,-1)==self.facing,
   v(0,1)==self.facing
  }
  return c_push_vel,{allowed_dirs,1}
 end
end

-------------------------------
-- entity: fireplace
-------------------------------

fireplace=entity:extend(
  {
    fr=2,ff=2,
    draw_order=2,
    lr=16
  }
)

fireplace:spawns_from(98)

function fireplace:init()
  add(lightpoints, self)
  self.fr=4
end

function fireplace:destroy()
  del(lightpoints, self)
end

function fireplace:update()
  p_add(smoke(
    {
      pos=v(self.pos.x+4+rnd(2)-1,self.pos.y+2+rnd(2)-1),
      c=rnd(1)<0.5 and 7 or 9
    }
  ))
end

-------------------------------
-- entity: dialogue box
-------------------------------
dialogue_box=entity:extend({
    is_talking=false,
    cursor=0,
    tspd=3,
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
        
        self.line_size = max(self.cursor/(self.offset+1)-1, self.line_size)
        if sub(self.lines[self.index], self.cursor, self.cursor) == '\n' then
        self.offset += 1
        end
    end
end

function dialogue_box:stop()
    self.running=false
end

function dialogue_box:start()
    self.running=true
    self.index=1
    self.cursor=0 self.offset=0 self.line_size=0
end

function dialogue_box:next()
    self.index+=1
    self.cursor=0 self.offset=0 self.line_size=0
    if (not self.running)self:start()
    if (self.index>#self.lines) self:stop()
end

function dialogue_box:render()
    if (not self.running) return
    local x,y=self.pos.x-10,self.pos.y-5-self.base_offset*self.offset
    if (self.cursor ~= 0) rectfill(x, y-1, x+4*self.line_size, y+6*(self.offset+1), 0)
    print(sub(self.lines[self.index], 0, self.cursor), x, y, 7)
end

-------------------------------
-- entity: old man
-------------------------------

old_man=dynamic:extend({
 collides_with={"player"},
 tags={"old_man"}, dir=v(1,0),
 hitbox=box(-8,-8,16,16),
 sprite=0,
 draw_order=3,
 ssize=3,
 inv_sp=30
})

old_man:spawns_from(2,128,129)

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
    print("x",self.pos.x+3,self.pos.y-6)
 end
end

-------------------------------
-- entity: light system
-------------------------------

lightpoints = {}

light_system=entity:extend({
 tags={"light_system"},
 draw_order=7,
 rects={},
 pt={0b0.1,0b0101101001011010.1,0b1111111111111111.1}
})

light_system:spawns_from(48)

function light_system:update()
  if current_level and not self.tpos then
    self.tpos = current_level.base
    self.ppos = current_level.pos
  end

  for i=0,15 do
    for j=0,15 do
      local ll=1
      for e in all(lightpoints) do
        local r=e.lr
        if r then
          local dist = v(
            abs(e.pos.x-(self.ppos.x+i*8)),
            abs(e.pos.y-(self.ppos.y+j*8))
          ):len()

          if dist < r then
            ll=3
          elseif dist < (r+8) and ll<2 then
            ll=2
          end
        end
      end
      self.rects[i*16+j] = {self.ppos.x+i*8,self.ppos.y+j*8,ll}
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
     pos=v(self.pos.x+4,self.pos.y-10),
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
  self.original_pos = self.pos
  self:become("idle")
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
  collides_with={"player"},
  tags={"door"},
  state="closed",
  draw_order=1,
  persistent=true
})

door:spawns_from(12)

function door:closed()
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
  if self.t%4 then
    local p=self.pos+v(2+rnd(10), 2+rnd(10))
    add_explosion(p,2)
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

gate=entity:extend({
  hitbox=box(-8,-8,8,8),
  collides_with={"key", "player"},
  tags={"gate"},
  kspr=13,
  kcount=3,
  off=v(8,8),
  persistent=true
})

gate:spawns_from(11)

function gate:init() self.pos+=self.off end

function gate:dead()
  if (self.t==60) self.done=true
  if self.t%4 then
    local p=self.pos-self.off+v(2+rnd(10), 2+rnd(10))
    add_explosion(p,2)
  end
end

function gate:render()
  spr(self.sprite, self.pos.x-self.off.x, self.pos.y-self.off.y, 2, 2)

  local off=-1
  for i=1,self.kcount do
    spr(self.kspr, self.pos.x-self.off.x+off, self.pos.y-self.off.y+6)
    off+=5
  end
end

function gate:collide(e)
  if e:is_a("key") then
    self.kcount-=1
    if(self.kcount<=0) self:become("dead")
    return
  end
  
  return c_push_out
end

-------------------------------
-- entity: slowdown
-------------------------------

slowdown=entity:extend({
  hitbox=box(0,0,8,8),
  tags={"slowdown"},
  collides_with={"player","enemy"},
  draw_order=1
})

slowdown:spawns_from(56)

function slowdown:collide(e)
  if e.basevel then
    e.maxvel=e.basevel/2
  end
end

-------------------------------
-- entity: button
-------------------------------

button=entity:extend({
  hitbox=box(0,0,8,8),
  collides_with={"player","enemy"},
  tags={"button"},
  draw_order=1
})

button:spawns_from(21)

function button:pressed()
  if self.t==0 then
    add_explosion(self.pos+v(0,6),3,8,2)
  end
  self.sprite=22
end

function button:released()
  self.sprite=21
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