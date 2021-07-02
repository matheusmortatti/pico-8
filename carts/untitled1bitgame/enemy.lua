------------------------------------
-- enemies
------------------------------------

-------------------------------
-- entity: enemy
-------------------------------

enemy=dynamic:extend({
  collides_with={"player"},
  tags={"enemy"},
  hitbox=box(0,0,8,8),
  c_tile=true,  
  inv_t=30,
  ht=0,
  hit=false,
  sprite=26,
  draw_order=4,
  death_time=15,
  health=1,
  give=10,
  take=1,
  ssize=1,
  svel=0.1
})

enemy:spawns_from(19)

function enemy:spawn_condition(em)
  if (not em) return true
  return time()-em[1]>self.give*self.health/2
end

function enemy:init()
  if self.sprite==19 then self.ssize=2 end
end

function enemy:enemy_update()
    self.ht+=1

    if (self.hit) self.dir=v(0,0)

    if self.ht > self.inv_t then
        self.hit=false
        self.ht=0
    end
end

function enemy:update()
    self:enemy_update()
end

function enemy:dead()
  if self.t > self.death_time then
    --mset(self.map_pos.x,self.map_pos.y,0)
    self.done=true
    entity_map[tostr(self.map_pos.x) .. "," .. tostr(self.map_pos.y)]={time()}
  end
end

function enemy:damage(s)
  if not self.hit then
    self.health-=1
    s=s or 1
    
    if (self.health <=0) then
    	self:become("dead")
    	s*=2
    end
    
    add_time(self.give*s)
    p_add(ptext({
      pos=v(self.pos.x-10,self.pos.y),
      txt="+"..self.give*s,
      lifetime=45
      }))
    self.hit=true
    shake=5
    self.ht=0
  end 
end

function enemy:collide(e)
  enemy_collide(self, e)
end

function enemy_collide(self, e)
  if (self.state=="dead") return
  if e:is_a("player") and e.damage and e:damage() then
    local d=v(e.pos.x-self.pos.x,e.pos.y-self.pos.y)
    if #d>0.01 then d=d:norm() end
    e.vel=d*3
    add_time(-self.take)
  end
end

function enemy:render()
  self:shared_render()
end

function enemy:shared_render()
  if (self.hit and self.t%3==0) return
  local s=self.sprite
  s+=(self.t*self.svel)%self.ssize
  self.flip=self.dir.x<0 and true or false
  spr(s,self.pos.x,self.pos.y,1,1,self.flip)

  if self.state=="dead" then
    self:draw_dit(self.t, self.death_time, true)
  end
end

-------------------------------
-- entity: bat
-------------------------------

bat=enemy:extend({
  hitbox=box(1,0,8,5),
  collides_with={"player"},
  draw_order=5,
  state="idle",
  attack_dist=10*60,
  vel=v(0,0),
  maxvel=0.3,  
  fric=0.1,
  acc=2,
  health=2,
  c_tile=false
})

bat:spawns_from(55)

function bat:idle()
  if not scene_player then return end
  local dist=#dist_vector(scene_player.pos,self.pos)
  if dist < self.attack_dist then 
    self:become("attacking")
    self.sprite=53
    self.ssize=2
    self.svel=0.05
  end
end

function bat:attacking()
  if not scene_player then return end

  self.dir=dist_vector(scene_player.pos,self.pos):norm()
  self:set_vel()

  self.pos += v(0, 0.5*sin(self.t/40+0.5))
end

-------------------------------
-- entity: spike
-------------------------------

spike=enemy:extend({
  hb=box(0,0,7,7),
  hitbox=nil,
  collides_with={"player"},
  tags={},
  draw_order=1,
  state="low"
})

spike:spawns_from(116,115)

function spike:init()
  if (self.sprite==115) self.ps="waiting" self:become("waiting")
end

function spike:waiting()
  if self.p==nil and self.pv~=nil then
    self:become("high")
    add_explosion(self.pos+v(0,6),3,8,2)
  end
  self.pv=self.p
  self.p=nil
end

function spike:low()
  self.hitbox=nil
  self.sprite=nil
  if (self.t>60) self:become("mid")
end

function spike:mid()
  self.hitbox=nil
  self.sprite=115
  if self.t>60 then 
    self:become("high")
    add_explosion(self.pos+v(0,6),3,8,2)
  end
end

function spike:high()
  self.hitbox = self.hb
  self.sprite=116
  if (self.t>90 and self.ps~="waiting") self:become("low")

end

function spike:collide(e)
  if self.state=="high" then
    enemy_collide(self, e)
  elseif self.state=="waiting" then
    self.p=e
  end
end

-------------------------------
-- entity: block
-------------------------------

-- block=enemy:extend({
--   hitbox=box(1,1,15,15),
--   state="idle",
--   maxvel=3,
--   basevel=3,
--   fric=1
-- })

-- block:spawns_from(41)

-- function block:init()
--   self.orig=v(self.pos.x,self.pos.y)
-- end

-- function block:idle()
--   self.sprite=41
--   if(not scene_player)return
--   local v=scene_player.pos-self.pos
--   local ang=atan2(v.x,v.y)
  
--   if (ang > 0.24 and ang < 0.26) or
--     (ang > 0.49 and ang < 0.51) or
--     (ang > 0.74 and ang < 0.76) or
--     (ang > 0.99 or ang < 0.01) then
--     self:become("charging")
--     self.dir=v:norm()
--     if abs(self.dir.x)>abs(self.dir.y) then
--       self.dir.y=0
--     else 
--       self.dir.x=0
--     end
--   end
-- end

-- function block:charging()
--   self.sprite=43
--   if self.t>15 then
--     self:set_vel()
--   end
--   self.maxvel=self.basevel
-- end

-- function block:back()
--   if (self.t<15) return
--   self.sprite=41
--   local d=(self.orig-self.pos)
--   if #d < #self.vel then
--     self:become("idle")
--     self.pos=v(self.orig.x,self.orig.y)
--     self.vel=v(0,0)
--   else
--     self.dir=d:norm()
--     self:set_vel()
--   end
--   self.maxvel=self.basevel
-- end

-- function block:collide(e)
--   if (self.state=="charging")enemy_collide(self, e)
--   if self.state~="back" then
--     self.vel=v(0,0)
--     shake+=2
--   end
--   self:become("back")
-- end

-- function block:tcollide()
--   self:become("back")
--   shake+=2
-- end

-- function block:render()
--   spr(self.sprite, self.pos.x, self.pos.y, 2, 2)
-- end

-------------------------------
-- entity: blob
-------------------------------

blob=enemy:extend({
  state="moving",
  vel=v(0,0),
  hitbox=box(1,3,7,8),  
  maxvel=0.5,
  spd=1,
  health=1
})

blob:spawns_from(7)

function blob:init()
  self.fric=0.05
  self.ssize=3
  self.svel=0.15
end

function blob:moving()
  if not scene_player then return end

  self.dir=v(scene_player.pos.x-self.pos.x,
             scene_player.pos.y-self.pos.y):norm()

  self.maxvel = self.spd*(cos(self.t/20)+1)/2 + 0.1

  self:set_vel()
end

-------------------------------
-- entity: charger
-------------------------------

charger=enemy:extend({
  collides_with={"player","attack","door","gate"},
  hitbox=box(0,0,8,8),
  state="choosing",
  maxvel=0.5,
  basevel=0.5,
  fric=1,
  mindist=8,maxdist=32,
  health=3
})

charger:spawns_from(21)

function charger:update()
    self:enemy_update()

    if not scene_player or 
       self.state=="frozen" or 
       self.state=="charging" or 
       self.state=="dead" then
      return
    end

    if self.hit then
      self:become("frozen")
    end

    local v=scene_player.pos-self.pos
    local ang=atan2(v.x,v.y)

    if (ang > 0.24 and ang < 0.26) or
        (ang > 0.49 and ang < 0.51) or
        (ang > 0.74 and ang < 0.76) or
        (ang > 0.99 or ang < 0.01) then
        self:become("charging")
        self.dir=v:norm()
        if abs(self.dir.x)>abs(self.dir.y) then
        self.dir.y=0
        else 
        self.dir.x=0
        end
    end
end

function charger:charging()
    if self.t>15 then
        self:set_vel()
        self.sprite=22
        self.ssize=4
    end
    self.maxvel=self.basevel*4
end

function charger:choosing()
    self.maxvel=self.basevel
    self.vel=v(0,0)
    self.sprite=21
    self.ssize=1
    if self.t<60 then return end
    self.dir=v(rnd(2)-1,rnd(2)-1):norm()
    self.target=self.pos+
        self.dir*(rnd(self.maxdist-self.mindist)+self.mindist)

    self:become("walking")
    self.sprite=22
    self.ssize=4
end

function charger:walking()
  local d=(self.target-self.pos)
  if #d < #self.vel then
    self:become("choosing")
    self.pos=v(self.target.x,self.target.y)
  else
    self.dir=d:norm()
    self:set_vel()
  end
end

function charger:frozen()
  self.sprite=21
  self.ssize=1
  self.vel=v(0,0)
  if (self.t>30) self:become("choosing")
end

function charger:collide(e)
  if self.state=="dead" then return end
  if self.state!="frozen" then enemy_collide(self, e) end
  if self.state=="charging" or self.state=="frozen" then 
    shake=2 
    self:become("frozen") 
    return 
  end
  self:become("choosing")
end

function charger:tcollide()
  if self.state=="dead" or self.state=="frozen" then return end
  if self.state=="charging" then shake=2 self:become("frozen") return end
  self:become("choosing")
end

function charger:render()
  if (self.state=="frozen" and self.t%10>5) pal(8,7)
  self:shared_render()
  reset_pal()
end

-------------------------------
-- entity: laser dude
-------------------------------

laserdude=enemy:extend(
  {
    state="wondering",
    vel=v(0,0),
    hitbox=box(-4,-4,4,4),
    health=4,
    give=4,
    take=2,
    fric=0.07,
    r=5
  }
)

laserdude:spawns_from(10)

function laserdude:shooting()
  self.vel=v(0,0)

  local llength=5
  if self.t==10 then
    shake+=5
    -- for i=0,llength-1 do
    --   local l=laser({dir=v(0,-1),pos=v(self.pos.x-self.r+1,self.pos.y-self.r-i*8)})
    --   l.lifetime=10+i
    --   e_add(l)
    --   l=laser({dir=v(0,1),pos=v(self.pos.x-self.r+1,self.pos.y+self.r+i*8)})
    --   l.lifetime=10+i
    --   e_add(l)
    --   l=laser({dir=v(1,0),pos=v(self.pos.x+self.r+i*8,self.pos.y-self.r+1)})
    --   l.lifetime=10+i
    --   e_add(l)
    --   l=laser({dir=v(-1,0),pos=v(self.pos.x-self.r-i*8,self.pos.y-self.r+1)})
    --   l.lifetime=10+i
    --   e_add(l)
    -- end

    e_add(bullet({dir=v(0,-1),pos=v(self.pos.x-self.r,self.pos.y-self.r)}))
    e_add(bullet({dir=v(1,0),pos=v(self.pos.x+self.r,self.pos.y+self.r/2)}))
    -- l=bullet({dir=v(1,0),pos=v(self.pos.x+self.r,self.pos.y-self.r+1)})
    -- l.lifetime=10
    -- e_add(l)
    -- l=bullet({dir=v(-1,0),pos=v(self.pos.x-self.r,self.pos.y-self.r+1)})
    -- l.lifetime=10
    -- e_add(l)

  end
  if self.t > 30 then
    self:become("wondering")
  end
end

function laserdude:wondering()
  local wonder_time=60
  if self.t > wonder_time and not self.hit then
    self:become("shooting")
  end

  if self.t == 1 then
    self.dir=v(rnd(2)-1,rnd(2)-1)*0.5
  end

  self:set_vel()
end

function laserdude:render()
  if self.hit and self.t%3==0 then return end
  circ(self.pos.x,self.pos.y,self.r,9)
  print("\130",self.pos.x-3,self.pos.y-2,9)

  if self.state=="dead" then
    self:draw_dit(self.t,self.death_time,true)
  end
end

laser=entity:extend(
  {
    hitbox=box(0,0,8,8),
    give=4,
    take=2,
    dir=v(1,0),
    collides_with={"player","oldman"},
    c_tile=false
  }
)

function laser:init()
  if (not self.lifetime) self.lifetime=10
  self.hitbox=box(0,0,8,8)

  if self.dir.x<0 then
    self.hitbox.xl=-8
    self.hitbox.xr=0
  end

  if self.dir.y<0 then
    self.hitbox.yt=-8
    self.hitbox.yb=0
  end

  if self.dir.x~=0 then
    self.hitbox.yt=3
    self.hitbox.yb=5
  end

  if self.dir.y~=0 then
    self.hitbox.xl=3
    self.hitbox.xr=5
  end
end

function laser:update()
  if (self.t>self.lifetime) self.done=true
end

laser.collide=enemy.collide

function laser:render()
  rectfill(self.hitbox.xl+self.pos.x,self.hitbox.yt+self.pos.y,
           self.hitbox.xr+self.pos.x,self.hitbox.yb+self.pos.y,9)
  if self.t >= 3*self.lifetime/4 then
    self:draw_dit((self.lifetime-self.t),(self.lifetime/4),false)    
  end
end

-------------------------------
-- entity: bullet
-------------------------------

bullet=enemy:extend({
    collides_with={"player"},
    tags={"bullet"},
    hitbox=box(-1,-1,1,1),
    vel=v(0,0),
    maxvel=2,
    c_tile=true,
    lifetime=30,
    r=3
})

function bullet:init()
  
end

function bullet:update()
  self:enemy_update()
  self:set_vel()
  printh(self.pos:str())

  if (self.t > self.lifetime) self.done=true
end

function bullet:render()
  circfill(self.pos.x, self.pos.y, 3)
end
