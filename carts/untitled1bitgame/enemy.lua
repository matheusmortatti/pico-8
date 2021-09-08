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
  give=3,
  take=2,
  ssize=1,
  svel=0.1
})

enemy:spawns_from(19)

function enemy:spawn_condition(em)
  if (not em) return true
  return time()-em[1]>self.give*self.health*2
end

function enemy:init()
  if self.sprite==19 then self.ssize=2 end
end

function enemy:enemy_update()
    if (self.hit) self.ht+=1

    if self.ht > self.inv_t then
        self.hit=false
        self.ht=0
    elseif self.ht>self.inv_t/3 then
      self.dir=zero_vector()
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
  if not self.hit and not self.invincible then
    s=s or 1
    self.health-=s
    
    if (self.health <=0) then
    	self:become("dead")
    	s*=1.3
    end
    
    local t=ceil(self.give*s*multiplier)
    add_time(t)
    p_add(ptext({
      pos=v(self.pos.x-10,self.pos.y),
      txt="+"..t,
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
  if e:is_a("player") and e.damage and e:damage(self.take) then
    local d=e.pos-self.pos
    if #d>0.01 then d=d:norm() end
    e.vel=d*3
    add_time(-self.take)
  end
end

function enemy:render()
  shared_render(self)
end

function shared_render(self)
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
  attack_dist=600,
  vel=zero_vector(),
  maxvel=0.3,  
  fric=0.05,
  acc=0.05,
  health=2,
  give=6,
  take=5,
  sprite=55,
  c_tile=false
})

bat:spawns_from(55)

function bat:idle()
  local dist=#dist_vector(scene_player.pos,self.pos)
  if dist < self.attack_dist then 
    self:become("attacking")
  end
end

function bat:attacking()
  self.sprite=53
  self.ssize=2
  self.svel=0.05
  
  self.pos += v(0, 0.5*sin(self.t/40+0.5))
  self:follow_player()
end

function bat:follow_player()
  self.dir=dist_vector(scene_player.pos,self.pos):norm()
  self:set_vel()
end

-------------------------------
-- entity: blob
-------------------------------

blob=bat:extend({
  state="idle",
  vel=zero_vector(),
  hitbox=box(1,3,7,8),
  spd=0.9,
  sprite=7,
  health=1,
  give=5,
  c_tile=true,
  attack_dist=1200
})

blob:spawns_from(7)

function blob:attacking()
  self.fric=0.05
  self.ssize=3
  self.svel=0.15

  self:follow_player()
  self.maxvel = self.spd*(cos(self.t/20)+1)/2 + 0.1
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
  take=5,
  low_t=60,
  mid_t=60,
  high_t=90
})

spike:spawns_from(116,115)

function spike:init()
  if (self.sprite==115) self.high_t*=2 self.type=1 self:become("waiting")
end

function spike:low()
  self.sprite=nil
  if (self.t>self.low_t) self:become("mid")
end

function spike:mid()
  self.sprite=115
  if self.t>self.mid_t then 
    self:become("high")
    add_explosion(self.pos+v(0,6),3,8,2)
  end
end

function spike:high()
  self.sprite=116
  if self.t>self.high_t then 
    if self.type==1 then
      self:become("waiting")
      self.sprite=115
    else
      self:become("low")
    end
  end
end

function spike:collide(e)
  if self.state=="high" then
    enemy_collide(self, e)
  end
end

function spike:end_collision(e)
  if self.state=="waiting" then
    self:become("high")
    add_explosion(self.pos+v(0,6),3,8,2)
  end
end

-------------------------------
-- entity: charger
-------------------------------

charger=enemy:extend({
  collides_with={"player","door","gate"},
  state="choosing",
  maxvel=0.5,
  basevel=0.5,
  fric=1,
  mindist=8,maxdist=32,
  health=3,
  give=8,
  take=10,
  inv_t=90,
  bh=box(-128,-2,128,10),
  bv=box(-2,-128,10,128)
})

charger:spawns_from(21)

function charger:init()
  self.level_pos=level_index*128
end

function charger:update()
  if (self.hit) self.ht+=1

  if self.ht > self.inv_t then
      self.hit=false
      self.ht=0
  end

  local last_pos=self.pos:copy()
  self.pos.x=clamp(self.level_pos.x,self.level_pos.x+120,self.pos.x)
  self.pos.y=clamp(self.level_pos.y,self.level_pos.y+120,self.pos.y)
  if(last_pos!=self.pos) self:become("frozen")

  if not scene_player or 
      self:is_in_any_state("frozen","charging","dead") then
    return
  end

  local p=c_get_entity(scene_player)
  if p.b:overlaps(self.bv:translate(self.pos)) or
     p.b:overlaps(self.bh:translate(self.pos))then
    self:become("charging")
    self.dir=(scene_player.pos-self.pos):norm()
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
    else
      self.vel=zero_vector()
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
  if self.state!="frozen" then 
    enemy_collide(self, e) 
  end
  if self.state=="charging" then 
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

function charger:hit_reaction()
  if (self.state!="dead") self:become("frozen")
end

function charger:render()
  if self.state=="frozen" and self.t%10>5 then 
    pal(8,7)
  end
  shared_render(self)
  reset_pal()
  local bv,bh=self.bv:translate(self.pos),self.bh:translate(self.pos)
end

-------------------------------
-- entity: laser dude
-------------------------------

laserdude=enemy:extend(
  {
    state="wondering",
    vel=zero_vector(),
    hitbox=box(1,1,6,6),
    health=2,
    give=4,
    take=2,
    inv_t=60,
    fric=0.01,acc=0.05,
    r=5
  }
)

laserdude:spawns_from(10)

function laserdude:shooting()
  self.vel=zero_vector()

  local llength=5
  if self.t%7==0 then
    shake+=5

    local x,y,r=self.pos.x,self.pos.y
    e_add(bullet({dir=v(0,-1),pos=v(x+4,y)}))
    e_add(bullet({dir=v(0,1),pos=v(x+4,y+8)}))
    e_add(bullet({dir=v(1,0),pos=v(x+8,y+4)}))
    e_add(bullet({dir=v(-1,0),pos=v(x,y+4)}))

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

-------------------------------
-- entity: bullet
-------------------------------

bullet=enemy:extend({
  collides_with={"player"},
  tags={"bullet"},
  hitbox=box(-1,-1,1,1),
  maxvel=2,
  take=5,
  c_tile=true,
  lifetime=60,
  r=2
})

function bullet:update()
  self:set_vel()
  -- if self.t%5==0 then
  --   local s=create_smoke(self.pos,2,2,1,1,7,9)
    
  --   s.vel=v(rnd(1)-0.5,rnd(1)-0.5)
  --   p_add(s)
  -- end

  if (self.t > self.lifetime) self.done=true
end

function bullet:render()
  circfill(self.pos.x,self.pos.y,self.r,8)
end

function bullet:collide(e)
  add_explosion(self.pos,2,2,2,1,1,7,8,0)
  enemy_collide(self, e)
  self.done=true
end

function bullet:tcollide()
  add_explosion(self.pos,2,2,2,-3,-1,7,8,0)
  self.done=true
end