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

function enemy:init()
  if self.sprite==19 then self.ssize=2 end
end

function enemy:update()
  self.ht+=1

  if (self.hit) self.dir=v(0,0)

  if self.ht > self.inv_t then
    self.hit=false
    self.ht=0
  end
end

function enemy:dead()
  if self.t > self.death_time then
    mset(self.map_pos.x,self.map_pos.y,0)
    self.done=true
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
  if e:is_a("player") and e.damage then
    if e:damage() then
      local d=v(e.pos.x-self.pos.x,e.pos.y-self.pos.y)
      if #d>0.01 then d=d:norm() end
      e.vel=d*3
      add_time(-self.take)
    end
  end
end

function enemy:render()
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

block=enemy:extend({
  hitbox=box(1,1,15,15),
  state="idle",
  maxvel=3,
  basevel=3,
  fric=1
})

block:spawns_from(41)

function block:init()
  self.orig=v(self.pos.x,self.pos.y)
end

function block:idle()
  self.sprite=41
  if(not scene_player)return
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

function block:charging()
  self.sprite=43
  if self.t>15 then
    self:set_vel()
  end
  self.maxvel=self.basevel
end

function block:back()
  if (self.t<15) return
  self.sprite=41
  local d=(self.orig-self.pos)
  if #d < #self.vel then
    self:become("idle")
    self.pos=v(self.orig.x,self.orig.y)
    self.vel=v(0,0)
  else
    self.dir=d:norm()
    self:set_vel()
  end
  self.maxvel=self.basevel
end

function block:collide(e)
  if (self.state=="charging")enemy_collide(self, e)
  if self.state~="back" then
    self.vel=v(0,0)
    shake+=2
  end
  self:become("back")
end

function block:tcollide()
  self:become("back")
  shake+=2
end

function block:render()
  spr(self.sprite, self.pos.x, self.pos.y, 2, 2)
end

-------------------------------
-- entity: charger
-------------------------------

charger=enemy:extend({
  hitbox=box(0,0,8,8),
  state="choosing",
  maxvel=0.5,
  basevel=0.5,
  fric=1,
  mindist=8,maxdist=32
})

charger:spawns_from(21)

function charger:update()
    if(not scene_player)return
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
    end
    self.maxvel=self.basevel
end

function charger:choosing()
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

function charger:tcollide()
  if self.state=="dead" then return end
  self:become("choosing")
end