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
    if (self.hit) self.ht+=1 self.dir=zero_vector()

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

    if (self.hit_reaction) self:hit_reaction()
  end 
end

function enemy:collide(e)
  enemy_collide(self, e)
end

function enemy_collide(self, e)
  if (self.state=="dead") return
  if e:is_a("player") and e.damage and e:damage() then
    local d=e.pos-self.pos
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
  vel=zero_vector(),
  maxvel=0.3,  
  fric=0.1,
  acc=2,
  health=2,
  sprite=55,
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
  state="low",
  low_t=60,
  mid_t=60,
  high_t=90
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
  if (self.t>self.low_t) self:become("mid")
end

function spike:mid()
  self.hitbox=nil
  self.sprite=115
  if self.t>self.mid_t then 
    self:become("high")
    add_explosion(self.pos+v(0,6),3,8,2)
  end
end

function spike:high()
  self.hitbox = self.hb
  self.sprite=116
  if (self.t>self.high_t and self.ps~="waiting") self:become("low")

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
  vel=zero_vector(),
  hitbox=box(1,3,7,8),  
  maxvel=0.5,
  spd=1,
  sprite=7,
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

  self.dir=(scene_player.pos-self.pos):norm()

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

    local level_pos=level_index*128
    local last_pos=self.pos:copy()
    self.pos.x=clamp(level_pos.x,level_pos.x+120,self.pos.x)
    self.pos.y=clamp(level_pos.y,level_pos.y+120,self.pos.y)
    if(last_pos!=self.pos) self:become("frozen")

    if not scene_player or 
       self:is_in_any_state("frozen","charging","dead") then
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
    self.vel=zero_vector()
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
    self.pos=self.target:copy()
  else
    self.dir=d:norm()
    self:set_vel()
  end
end

function charger:frozen()
  self.sprite=21
  self.ssize=1
  self.vel=zero_vector()
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
    vel=zero_vector(),
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
  self.vel=zero_vector()

  local llength=5
  if self.t==10 then
    shake+=5

    e_add(bullet({dir=v(0,-1),pos=v(self.pos.x,self.pos.y-self.r/2)}))
    e_add(bullet({dir=v(0,1),pos=v(self.pos.x,self.pos.y+self.r)}))
    e_add(bullet({dir=v(1,0),pos=v(self.pos.x+self.r/2,self.pos.y)}))
    e_add(bullet({dir=v(-1,0),pos=v(self.pos.x-self.r/2,self.pos.y)}))

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

-------------------------------
-- entity: bullet
-------------------------------

bullet=dynamic:extend({
  collides_with={"player"},
  tags={"bullet"},
  hitbox=box(-1,-1,1,1),
  maxvel=2,
  c_tile=true,
  lifetime=30,
  r=3
})

function bullet:update()
  self:set_vel()
  if self.t%5==0 then
    local s=create_smoke(self.pos,2,2,1,1,7,9)
    
    s.vel=v(rnd(1)-0.5,rnd(1)-0.5)
    p_add(s)
  end

  if (self.t > self.lifetime) self.done=true
end

function bullet:render()
  circfill(self.pos.x,self.pos.y,self.r,9)
end

function bullet:collide(e)
  add_explosion(self.pos,2,2,2,1,1,7,9,0)
  if e.damage then
    if e:damage() then
      e.vel=self.dir*3
    end
  end
  self.done=true
end

function bullet:tcollide()
  add_explosion(self.pos,2,2,2,-3,-1,7,9,0)
  self.done=true
end

-------------------------------
-- entity: spawner
-------------------------------

enemy_list={charger, blob, laserdude, bat}

spawner=enemy:extend({
  collides_with={"player"},
  state="spawn",
  hitbox=box(0,0,8,8),
  maxvel=2,
  c_tile=true,
  spawn_time=10*30,
  svel=0.2,
  spawn_number=2,
  spawn_limit=5,
  spawn_list={}
})

spawner:spawns_from(45)

function spawner:cooldown()
  self:become("spawn")
end

function spawner:spawn()
  self:manage_spawn_list()
  if self.t>=self.spawn_time then
    if #self.spawn_list < self.spawn_limit then
      for i=1,self.spawn_number do
        local dirs={
          v(-1,0),v(1,0),v(0,-1),v(0,1),
          v(-1,-1),v(1,1),v(1,-1),v(-1,1)}
        local mp=v(self.map_pos.x, self.map_pos.y)
        local e=enemy_list[flr(rnd(#enemy_list)+1)]

        mp+=dirs[flr(rnd(#dirs)+1)]
        
        local e_inst=e({
          pos=mp*8,
          vel=zero_vector(),
          map_pos=mp
        })
        e_add(e_inst)
        add(self.spawn_list, e_inst)

        add_explosion(e_inst.pos,2,2,2,-3,-1,7,9,0)

        if (e==bat) e_inst.attack_dist=10000
      end
    end
    self:become("cooldown")
  end
end

function spawner:manage_spawn_list()
  for e in all(self.spawn_list) do
    if e.done then
      del(self.spawn_list, e)
    end
  end
end