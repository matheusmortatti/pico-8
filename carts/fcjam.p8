pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

debug=false

function deep_copy(obj)
 if (type(obj)~="table") return obj
 local cpy={}
 setmetatable(cpy,getmetatable(obj))
 for k,v in pairs(obj) do
  cpy[k]=deep_copy(v)
 end
 return cpy
end

function shallow_copy(obj)
  if (type(obj)~="table") return obj
 local cpy={} 
 for k,v in pairs(obj) do
  cpy[k]=v
 end
 return cpy
end


-- creates a new object by calling obj = object:extend()
object={}
function object:extend(kob)
  kob=kob or {}
  kob.extends=self
  return setmetatable(kob,{
   __index=self,
   __call=function(self,ob)
	   ob=setmetatable(ob or {},{__index=kob})
	   local ko,init_fn=kob
	   while ko do
	    if ko.init and ko.init~=init_fn then
	     init_fn=ko.init
	     init_fn(ob)
	    end
	    ko=ko.extends
	   end
	   return ob
  	end
  })
end

vector={}
vector.__index=vector
 -- operators: +, -, *, /
 function vector:__add(b)
  return v(self.x+b.x,self.y+b.y)
 end
 function vector:__sub(b)
  return v(self.x-b.x,self.y-b.y)
 end
 function vector:__mul(m)
  return v(self.x*m,self.y*m)
 end
 function vector:__div(d)
  return v(self.x/d,self.y/d)
 end
 function vector:__unm()
  return v(-self.x,-self.y)
 end
function vector:__neq(v)
  return not (self.x==v.x and self.y==v.y)
end
function vector:__eq(v)
  return self.x==v.x and self.y==v.y
end
 -- dot product
 function vector:dot(v2)
  return self.x*v2.x+self.y*v2.y
 end
 -- normalization
 function vector:norm()
  return self/sqrt(#self)
 end
 -- length
 function vector:len()
  return sqrt(#self)
 end
 -- the # operator returns
 -- length squared since
 -- that's easier to calculate
 function vector:__len()
  return self.x^2+self.y^2
 end
 -- printable string
 function vector:str()
  return self.x..","..self.y
 end

-- creates a new vector with
-- the x,y coords specified
function v(x,y)
 return setmetatable({
  x=x,y=y
 },vector)
end


-------------------------------
-- entity: base
-------------------------------

entity=object:extend(
  {
    t=0,
    spawns={}
  }
)

 -- common initialization
 -- for all entity types
function entity:init()  
  if self.sprite then
   self.sprite=deep_copy(self.sprite)
   if not self.render then
    self.render=spr_render
   end
  end
end
 -- called to transition to
 -- a new state - has no effect
 -- if the entity was in that
 -- state already
function entity:become(state)
  if state~=self.state then
   self.state,self.t=state,0
  end
end
-- checks if entity has 'tag'
-- on its list of tags
function entity:is_a(tag)
  if (not self.tags) return false
  for i=1,#self.tags do
   if (self.tags[i]==tag) return true
  end
  return false
end
 -- called when declaring an
 -- entity class to make it
 -- spawn whenever a tile
 -- with a given number is
 -- encountered on the level map
function entity:spawns_from(...)
  for tile in all({...}) do
   entity.spawns[tile]=self
  end
end


-------------------------------
-- collision boxes
-------------------------------

-- collision boxes are just
-- axis-aligned rectangles
cbox=object:extend()
 -- moves the box by the
 -- vector v and returns
 -- the result
 function cbox:translate(v)
  return cbox({
   xl=self.xl+v.x,
   yt=self.yt+v.y,
   xr=self.xr+v.x,
   yb=self.yb+v.y
  })
 end

 -- checks if two boxes
 -- overlap
 function cbox:overlaps(b)
  return
   self.xr>b.xl and
   b.xr>self.xl and
   self.yb>b.yt and
   b.yb>self.yt
 end

 -- calculates a vector that
 -- neatly separates this box
 -- from another. optionally
 -- takes a table of allowed
 -- directions
function cbox:sepv(b,allowed)
  local candidates={
    v(b.xl-self.xr,0),
    v(b.xr-self.xl,0),
    v(0,b.yt-self.yb),
    v(0,b.yb-self.yt)
  }
  if type(allowed)~="table" then
   allowed={true,true,true,true}
  end
  local ml,mv=32767
  for d,v in pairs(candidates) do
   if allowed[d] and #v<ml then
    ml,mv=#v,v
   end
  end

  return mv
end
 
 -- printable representation
 function cbox:str()
  return self.xl..","..self.yt..":"..self.xr..","..self.yb
 end

-- makes a new box
function box(xl,yt,xr,yb) 
 return cbox({
  xl=min(xl,xr),xr=max(xl,xr),
  yt=min(yt,yb),yb=max(yt,yb)
 })
end
-- makes a box from two corners
function vbox(v1,v2)
 return box(v1.x,v1.y,v2.x,v2.y)
end

-------------------------------
-- entity: dynamic
-------------------------------

dynamic=entity:extend({
    maxvel=1,
    acc=0.5,
    fric=0.5,
    vel=v(0,0),
    dir=v(0,0)
  })

function dynamic:set_vel()  
  if (self.vel.x<0 and self.dir.x>0) or
     (self.vel.x>0 and self.dir.x<0) or
     (self.dir.x==0) then     
    self.vel.x=approach(self.vel.x,0,self.fric)
  else
    self.vel.x=approach(self.vel.x,self.dir.x*self.maxvel,self.acc)
  end

  if (self.vel.y<0 and self.dir.y>0) or
     (self.vel.y>0 and self.dir.y<0) or
     (self.dir.y==0) then
    self.vel.y=approach(self.vel.y,0,self.fric)
  else
    self.vel.y=approach(self.vel.y,self.dir.y*self.maxvel,self.acc)
  end
end

-------------------------------
-- entity: enemy
-------------------------------

enemy=dynamic:extend({
  collides_with={"player"},
  tags={"enemy"},
  c_tile=true,
  hitbox=box(0,0,7,7),
  inv_t=30,
  ht=0,
  hit=false,
  sprite=26,
  draw_order=4,
  death_time=15,
  health=1,
  give=1,
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

function enemy:damage()
  if not self.hit then
    self.health-=1
    add_time(self.give)

    p_add(ptext({
      pos=v(self.pos.x-10,self.pos.y),
      txt="+"..self.give,
      lifetime=45
      }))
    self.hit=true
    shake=5
    self.ht=0    
  end

  if (self.health <=0) self:become("dead")
end

function enemy:collide(e)
  if (self.state=="dead") return
  if e:is_a("player") and e.damage then
    if e:damage() then
      local d=v(e.pos.x-self.pos.x,e.pos.y-e.pos.y)
      if #d>0.01 then d=d:norm() end
      e.vel=d*3
    end
  end
end

function enemy:render()
  if (self.hit and self.t%3==0) return
  local s=self.sprite
  s+=(self.t*self.svel)%self.ssize
  spr(s,self.pos.x,self.pos.y)

  if self.state=="dead" then
    draw_dithered(
      self.t/self.death_time,
      true,
      box(self.pos.x+self.hitbox.xl,
      self.pos.y+self.hitbox.yt,
      self.pos.x+self.hitbox.xr,
      self.pos.y+self.hitbox.yb)
      )
  end
end

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
end

function blob:moving()
  if not scene_player then return end

  self.dir=v(scene_player.pos.x-self.pos.x,
             scene_player.pos.y-self.pos.y):norm()

  self.maxvel = self.spd*(cos(self.t/20)+1)/2 + 0.1

  self:set_vel()
end

function blob:render()
  if (self.hit and self.t%3==0) return
  local s=self.sprite
  s+=(self.t*0.15)%3
  spr(s,self.pos.x,self.pos.y)

  if self.state=="dead" then
    draw_dithered(
      self.t/self.death_time,
      true,
      box(self.pos.x+self.hitbox.xl,
      self.pos.y+self.hitbox.yt,
      self.pos.x+self.hitbox.xr,
      self.pos.y+self.hitbox.yb)
      )
  end
end

-------------------------------
-- entity: blob
-------------------------------

spike=entity:extend({
  state="first",
  collides_with={"player"},
  hitbox=box(0,0,7,7),
  time=30,
  draw_order=1
})

spike:spawns_from(115)

function spike:first()
  if (self.t > self.time) self:become("second")
end

function spike:second()
  if (self.t > self.time) self:become("third")
end

function spike:third()
  if self.t==1 then
    for i=1,8 do
      local s=smoke({
        pos=v(self.pos.x+4+rnd(8)-4,self.pos.y+4+rnd(8)-4),
        vel=v(rnd(0.5)-0.25,-(rnd(1)+0.5))
        })
      s.r=rnd(0.7)+0.5
      e_add(s)
    end
    shake+=1
  end
  if (self.t > self.time) self:become("first")
end

function spike:render()
  if self.state=="second" then
    spr(self.sprite,self.pos.x,self.pos.y)
  elseif self.state=="third" then
    spr(self.sprite+1,self.pos.x,self.pos.y)
  end
end

function spike:collide(e)
  if self.state=="third" and e:is_a("player") and e.damage then
    if e:damage() then
      local d=v(e.pos.x-self.pos.x,e.pos.y-e.pos.y)
      if #d>0.001 then d=d:norm() end
      e.vel=d*3
    end
  end
end

-------------------------------
-- entity: time eater
-------------------------------

time_eater=enemy:extend(
  {
    state="idle",
    idle_time=60
  }
)
time_eater:spawns_from(1)

function time_eater:eating()
  add_time(-self.take)
  p_add(ptext({
      pos=v(self.pos.x-10,self.pos.y-4),
      txt="-"..self.take,
      lifetime=30,
      c=8
    }))

  for i=1,4 do
    e_add(smoke({
        pos=v(self.pos.x+4+rnd(2)-1,self.pos.y+rnd(2)-1),      
        c=rnd(1)<0.5 and 7 or 9}))
  end
  shake+=2
  self:become("idle")
end

function time_eater:idle()
  if (self.t > self.idle_time) self:become("eating")
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
    fric=0.07
  }
)

laserdude:spawns_from(10)

function laserdude:shooting()
  self.vel=v(0,0)
  
  if self.t%6 == 0 then
    e_add(bullet({
        dir=v(-1,0),
        pos=v(self.pos.x+self.hitbox.xl-8,
                self.pos.y),
        vel=v(0,0)
      }))

    e_add(bullet({
        dir=v(1,0),
        pos=v(self.pos.x+self.hitbox.xr+8,
                self.pos.y),
        vel=v(0,0)
      }))

    e_add(bullet({
        dir=v(0,-1),
        pos=v(self.pos.x,
                self.pos.y+self.hitbox.yt-8),
        vel=v(0,0)
      }))

    e_add(bullet({
        dir=v(0,1),
        pos=v(self.pos.x,
                self.pos.y+self.hitbox.yb+8),
        vel=v(0,0)
      }))
  end

  if self.t > 30 then
    self:become("wondering")
  end
end

function laserdude:wondering()
  local wonder_time=60
  if self.t > wonder_time and not self.hit then
    self:become("shooting")
    self.dir=v(0,0)    
  end

  if self.t == 1 then
    self.dir=v(rnd(2)-1,rnd(2)-1)*0.5
  end

  self:set_vel()
end

function laserdude:render()
  if self.hit and self.t%3==0 then return end
  circ(self.pos.x,self.pos.y,5,9)
  print("\130",self.pos.x-3,self.pos.y-2,9)


  if self.state=="dead" then
    draw_dithered(
      self.t/self.death_time,
      true,
      box(self.pos.x+self.hitbox.xl-1,
      self.pos.y+self.hitbox.yt-1,
      self.pos.x+self.hitbox.xr+1,
      self.pos.y+self.hitbox.yb+1)
      )
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

function bullet:init()
  self.wo=rnd(1)
end

function bullet:update()
  self.set_vel(self)

  if self.t%5==0 then
    local s=smoke({
        pos=v(self.pos.x+rnd(2)-1,self.pos.y+rnd(2)-1),      
        c=rnd(1)<0.5 and 7 or 9})
    s.vel=v(rnd(1)-0.5,rnd(1)-0.5)
    p_add(s)
  end

  self.pos.x+= self.dir.y*sin(self.t/5 + self.wo)
  self.pos.y+= self.dir.x*sin(self.t/5 + self.wo)

  if (self.t > self.lifetime) self.done=true
end

function bullet:render()
  circfill(self.pos.x,self.pos.y,self.r,9)
end

function bullet:collide(e)
  for i=1,2 do
    p_add(smoke({
      pos=v(self.pos.x+4+rnd(2)-1,self.pos.y+2+rnd(2)-1),
      c=rnd(1)<0.5 and 7 or 9
    }))
  end
  if e:is_a("player") and e.damage then
    if e:damage() then
      e.vel=self.dir*3
    end
  end
  self.done=true
end

function bullet:tcollide()
  for i=1,2 do
    p_add(smoke(
    {
      pos=v(self.pos.x+4+rnd(2)-1,self.pos.y+2+rnd(2)-1),
      c=rnd(1)<0.5 and 7 or 9
    }
  ))
  end
  self.done=true
end


-------------------------------
-- entity: old man
-------------------------------

oldman=enemy:extend({
  state="idle",
  vel=v(0,0),
  hitbox=box(1,3,7,8),
  maxvel=0.5
})

oldman:spawns_from(16)

function oldman:init()
  self.thinkchar="\138"
end

function oldman:idle()
  self:set_vel()

  if rnd(1)<0.05 then
    p_add(ptext(
      {
        pos=v(self.pos.x-4,self.pos.y-4),
        vh=true,
        txt=self.thinkchar
      }
    ))
  end
end

function oldman:collide(e)
  return c_push_out
end

function oldman:render()  
  local s=self.sprite
  s+=(self.t*0.1)%3
  spr(s,self.pos.x,self.pos.y)
  
  if self.state=="dead" then
    draw_dithered(
      self.t/self.death_time,
      true,
      box(self.pos.x+self.hitbox.xl-1,
      self.pos.y+self.hitbox.yt-1,
      self.pos.x+self.hitbox.xr+1,
      self.pos.y+self.hitbox.yb+1)
      )
  end
end

-------------------------------
-- entity: player
-------------------------------

player=dynamic:extend({
  state="walking", vel=v(0,0),
  collides_with={"enemy"},
  tags={"player"}, dir=v(1,0),
  hitbox=box(2,2,6,7),
  c_tile=true,
  sprite=0,
  draw_order=3,
  fric=0.5,
  inv_t=30,
  ht=0,
  hit=false
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

  if btnp(5) then 
    self:become("attacking")
  end  
end

function player:attacking()
  if not self.attk then
    local dir=self.last_dir.x~=0 and v(self.last_dir.x,0) or v(0, self.last_dir.y)
    self.attk=sword_attack(
      {
        pos=self.pos+dir*8,
        facing=dir
      }
    )
    e_add(self.attk)
  end

  self.vel=v(0,0)
  if self.attk.done then 
    self.attk=nil 
    self:become("walking")
  end
end

function player:render()
  if (self.hit and self.t%3==0) return

  local st=self.vel==v(0,0) and "idle" or "walking"
  local flip=false
  local spd=st=="idle" and 0 or 0.15
  self.sprite=st=="idle" and 32 or 33
  if self.last_dir.x<0 then
    flip=true
  end
  self.sprite+=flr(self.t*spd)%4

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

function player:collide(e)
  
end

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
    sprite=3,
    draw_order=5
  }
)

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
  if self.t <= self.lifetime/4 then
    draw_dithered(self.t/(self.lifetime/4))
    rectfill(pos.x,pos.y,pos.x+off.x,pos.y+off.y,0)
    fillp()
  end

  if self.t >= 3*self.lifetime/4 then
    draw_dithered((self.lifetime-self.t)/(self.lifetime/4))
    rectfill(pos.x,pos.y,pos.x+off.x,pos.y+off.y,0)
    fillp()
  end
end

function sword_attack:collide(e)
  if e:is_a("enemy") and not e.hit then
    e:damage()
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
    fr=2,ff=2
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
-- entity: chimney
-------------------------------

chimney=entity:extend(
  {
  }
)

chimney:spawns_from(76)

function chimney:update()
  if self.t%3==1 then
    p_add(smoke(
      {
        pos=v(self.pos.x+4+rnd(2)-1,self.pos.y+rnd(2)-1),
        r=rnd(0.95)+1
      }
    ))
  end
end

-------------------------------
-- entity: birb
-------------------------------

bird=entity:extend(
  {
    sing=0,
    draw_order=6
  }
)

bird:spawns_from(114)

function bird:update()
  if self.t%15==self.sing then
    self.sing=flr(rnd(10)+5)
    p_add(ptext(
      {
        pos=v(self.pos.x-4,self.pos.y-4),
        vh=true,
        txt="\141"
      }
    ))
  end
end

-------------------------------
-- level loading
-------------------------------

level_index=v(0,0)

function load_level()
  old_ent=shallow_copy(entities)  
  e_add(level({
    base=v(level_index.x*16,level_index.y*16),
    pos=v(level_index.x*128,level_index.y*128),
    size=v(16,16)
  }))
end

level=entity:extend({
 draw_order=1
})
 function level:init()
  -- start with a lit area. Any light_switches will make the room dark
  enable_light=false
  local b,s=
   self.base,self.size
  for x=0,s.x-1 do
   for y=0,s.y-1 do
    -- get tile number
    local blk=mget(b.x+x,b.y+y)    
    -- does this tile spawn
    -- an entity?
    local eclass=entity.spawns[blk]
    if eclass then
     -- yes, it spawns one
     -- let's do it!
     local e=eclass({
      pos=v(b.x+x,b.y+y)*8,
      vel=v(0,0),
      sprite=blk,
      map_pos=v(b.x+x,b.y+y)
     })     

     -- register the entity
    if e:is_a("player") and not scene_player then
      scene_player=e
      mset(b.x+x,b.y+y,0)
    end
    e_add(e)
     -- replace the tile
     -- with empty space
     -- in the map
     --mset(b.x+x,b.y+y,0)
     blk=0
    end
   end
  end
 end
 -- renders the level
 function level:render()
  map(self.base.x,self.base.y,
      self.pos.x,self.pos.y,
      self.size.x,self.size.y,0x1)
 end

-------------------------------
-- camera
-------------------------------

shake=0

cam=entity:extend(
  {
    tags={"camera"},
    spd=v(10,10),
    pos=level_index*128,
    draw_order=0,
    shk=v(0,0)
  }
)

function cam:update()
  self.pos.x=approach(self.pos.x,level_index.x*128,self.spd.x)
  self.pos.y=approach(self.pos.y,level_index.y*128,self.spd.y)

  if self.pos==level_index*128 then
    remove_old({"player","camera"})
  end

  if shake > 0 then
    shk=v(rnd(1)<0.5 and 1 or -1,rnd(1)<0.5 and 1 or -1)
    shake-=1
  else
    shake=0
    shk=v(0,0)
  end

  if scene_player then
    local p=scene_player
    local l_ind=v(flr((p.pos.x+p.hitbox.xl+(p.hitbox.xr-p.hitbox.xl)/2)/128),
                  flr((p.pos.y+p.hitbox.yt+(p.hitbox.yb-p.hitbox.yt)/2)/128))

    if level_index ~= l_ind then
      level_index=l_ind
      load_level()
    end
  end

  if enable_light then
    for l in all(lights) do
      l.pos=v(self.pos.x,self.pos.y)+l.off
      l:update()
    end
  end
end

function cam:render()  
  camera(self.pos.x+shk.x,self.pos.y+shk.y)
end


-------------------------------
-- light
-------------------------------

light=object:extend({
  l1=3,l2=2
})

function light:init()
  self.llevel=0
end

function light:update()
  local llevel=0
  for e in all(lightpoints) do
    local dist=flr(#(v(e.pos.x-self.pos.x,e.pos.y-self.pos.y)/8))
    local r=self.l1
    local fall=self.l2
    if e.fr then r=e.fr end
    if e.ff then fall=e.ff end

    if dist < r*r then 
      llevel=2
    elseif dist < (r+fall)*(r+fall) then 
      if llevel~=2 then llevel+=1 end
    end

  end

  self.llevel=llevel
end

function light:render()
  local p= self.llevel == 2 and 0b1111111111111111.1 or
           (self.llevel == 1 and 0b1010010110100101.1 or 0b0000000000000000.1)

  fillp(p)
  rectfill(self.pos.x,self.pos.y,self.pos.x+7,self.pos.y+7,0)
  fillp()
end

-------------------------------
-- entity: light switch
-------------------------------

light_switch=entity:extend({})

light_switch:spawns_from(48)

function light_switch:init()
  enable_light=true
end

function light_switch:render()
  return
end


-------------------------------------------------------------------
-- particles
--    common class for all
--    particles
-------------------------------------------------------------------

particle=object:extend(
  {
    t=0,vel=v(0,0),
    lifetime=30
  }
)

 -- common initialization
 -- for all entity types
function particle:init()  
  if self.sprite then
   self.sprite=deep_copy(self.sprite)
   if not self.render then
    self.render=spr_render
   end
  end
end

-------------------------------
-- smoke particle
-------------------------------

smoke=particle:extend(
  {
    vel=v(0,0),
    c=7
  }
)

function smoke:init()
  self.vel=v(rnd(0.5)-0.25,-(rnd(1)+0.5))
  if not self.r then self.r=rnd(1)+1.5 end
end

function smoke:update()
  self.r-=0.1
  if self.r<=0 then self.done=true end
end

function smoke:render()
  if (not self.pos) return  
  circfill(self.pos.x, self.pos.y, self.r, self.c)
end

-------------------------------
-- text particle
-------------------------------

ptext=particle:extend(
  {
    lifetime=20,
    txt="-1",
  }
)

function ptext:init()
  local vx=0
  if self.vh then vx=rnd(0.5)-0.5 end
  self.vel=v(vx,-(rnd(1)+0.5))
end

function ptext:update()
  if self.t > self.lifetime/3 then 
    self.vel=v(0,0) 
  end
end

function ptext:render()
  if (not self.pos) return


  rectfill(self.pos.x,self.pos.y,self.pos.x+4*#self.txt+2,self.pos.y+4,0)

  print(self.txt,self.pos.x,self.pos.y,self.c or 7)

  if self.t > 2*self.lifetime/3 then
    draw_dithered(
      (self.lifetime-self.t)/(2*self.lifetime/3),false,
      box(self.pos.x,self.pos.y,self.pos.x+4*#self.txt+2,self.pos.y+4))
  end
end


-------------------------------
-- fade particle
-------------------------------

fade=particle:extend(
  {
    vel=v(0,0),
    lifetime=15,
    c=0,
    follow=nil,
    rec=box(0,0,8,8),
    et=10,
    fadein=false
  }
)

function fade:init()

end

function fade:update()
  if self.follow then
    self.pos=self.follow.pos
  end
  if self.t>self.et then self.done=true end
end

function fade:render()
  if (not self.pos) return

  draw_dithered(self.t/self.et,fadein)
  rectfill(self.pos.x+self.hitbox.xl,
           self.pos.y+self.hitbox.yt,
           self.pos.x+self.hitbox.xr,
           self.pos.y+self.hitbox.yb,c)
  fillp()
end


-------------------------------
-- collision system
-------------------------------

function do_movement()
  for e in all(entities) do
    if (slowmo and (e_is_any(e,{"player","camera","attack"}) or slowmo_update)) or 
        (not slowmo) then
      if e.vel then
        e.pos.x+=e.vel.x
        collide_tile(e)        
        
        e.pos.y+=e.vel.y
        collide_tile(e)
      end
    end
  end
end

-------------
-- buckets
-------------

c_bucket = {}

function bkt_pos(e)
  local x,y=e.pos.x,e.pos.y
  return flr(shr(x,4)),flr(shr(y,4))
end

-- add entity to all the indexes
-- it belongs in the bucket
function bkt_insert(e)
  local x,y=bkt_pos(e)
  for t in all(e.tags) do
    local b=bkt_get(t,x,y)
    add(b,e)
  end

  e.bkt=v(x,y)
end

function bkt_remove(e)
  local x,y=e.bkt.x,e.bkt.y
  for t in all(e.tags) do
    local b=bkt_get(t,x,y)
    del(b,e)
  end
end

function bkt_get(t,x,y)
  local ind=t..":"..x..","..y
  if not c_bucket[ind] then
    c_bucket[ind]={}
  end
  return c_bucket[ind]
end

function bkt_update()  
  for e in all(entities) do
    bkt_update_entity(e)
  end
end

function bkt_update_entity(e)
  if not e.pos or not e.tags then return end
  local bx,by=bkt_pos(e)
  if not e.bkt or e.bkt.x~=bx or e.bkt.x~=by then
    if not e.bkt then
      bkt_insert(e)
    else
      bkt_remove(e)
      bkt_insert(e)
    end
  end
end

-- iterator that goes over
-- all entities with tag "tag"
-- that can potentially collide
-- with "e" - uses the bucket
-- structure described earlier.
function c_potentials(e,tag)
 local cx,cy=bkt_pos(e)
 local bx,by=cx-2,cy-1
 local bkt,nbkt,bi={},0,1
 return function()
  -- ran out of current bucket,
  -- find next non-empty one
  while bi>nbkt do
   bx+=1
   if (bx>cx+1) bx,by=cx-1,by+1
   if (by>cy+1) return nil
   bkt=bkt_get(tag,bx,by)
   nbkt,bi=#bkt,1
  end
  -- return next entity in
  -- current bucket and
  -- increment index
  local e=bkt[bi]
  bi+=1
  return e
 end 
end

function do_collisions()    
  	for e in all(entities) do
      collide(e)
    end
end

function collide(e)
  if not e.collides_with then return end
  if not e.hitbox then return end

  local ec=c_get_entity(e)

  ---------------------
  -- entity collision
  ---------------------
  for tag in all(e.collides_with) do
    --local bc=bkt_get(tag,e.bkt.x,e.bkt.y)
    for o in  c_potentials(e,tag) do  --all(entities[tag]) do
      -- create an object that holds the entity
      -- and the hitbox in the right position
      local oc=c_get_entity(o)
      -- call collide function on the entity
      -- that e collided with
      if o~=e and ec.b:overlaps(oc.b) then
        if ec.e.collide then 
          local func,arg=ec.e:collide(oc.e)
          if func then
            func(ec,oc,arg)            
          end
        end
      end

    end
  end
end


--------------------
-- tile collision
--------------------

function collide_tile(e)  
  -- do not collide if it's not set to
  if (not e.c_tile) return

  local ec=c_get_entity(e)

  local pos=tile_flag_at(ec.b, 1)

  for p in all(pos) do
    local oc={}
    oc.b=box(p.x,p.y,p.x+8,p.y+8)

    -- only allow pushing to empty spaces
    local dirs={v(-1,0),v(1,0),v(0,-1),v(0,1)}
    local allowed={}
    for i=1,4 do
      local np=v(p.x/8,p.y/8)+dirs[i]
      if np.x < 0 or np.x > 127 or np.y < 0 or np.y > 63 then
        allowed[i] = false
      else
        allowed[i]= not is_solid(np.x,np.y)
      end
    end

    if (ec.e.tcollide) ec.e:tcollide()
    c_push_out(oc, ec, allowed)
  end
end

-- get entity with the right position
-- for cboxes
function c_get_entity(e)
  local ec={}
  ec.e=e
  ec.b=e.hitbox--state_dependent(e,"hitbox")
  if (ec.b) ec.b=ec.b:translate(e.pos)
  return ec
end

-- returns an entity's property 
-- depending on entity state
-- e.g. hitbox can be specified
-- as {hitbox=box(...)}
-- or {hitbox={
--  walking=box(...),
--  crouching=box(...)
-- }
function state_dependent(e,prop)
 local p=e[prop]
 if (not p) return nil
 if type(p)=="table" and p[e.state] then
  p=p[e.state]
 end
 if type(p)=="table" and p[1] then
  p=p[1]
 end
 return p
end

function tile_at(cel_x, cel_y)
	return mget(cel_x, cel_y)
end

function is_solid(cel_x,cel_y)
  return fget(mget(cel_x, cel_y),1)
end

function tile_flag_at(b, flag)
  local pos={}

	for i=flr(b.xl/8), ((ceil(b.xr)-1)/8) do
		for j=flr(b.yt/8), ((ceil(b.yb)-1)/8) do
			if(fget(tile_at(i, j), flag)) then
				add(pos,{x=i*8,y=j*8})
			end
		end
	end

  return pos
end

-- reaction function, used by
-- returning it from :collide().
-- cause the other object to
-- be pushed out so it no
-- longer collides.
function c_push_out(oc,ec,allowed_dirs)
 local sepv=ec.b:sepv(oc.b,allowed_dirs)
 if not sepv then return end
 ec.e.pos+=sepv
 if ec.e.vel then
  local vdot=ec.e.vel:dot(sepv)
  if vdot<0 then   
   if sepv.x~=0 then ec.e.vel.x=0 end
   if sepv.y~=0 then ec.e.vel.y=0 end
  end
 end
 ec.b=ec.b:translate(sepv)
 end
-- inverse of c_push_out - moves
-- the object with the :collide()
-- method out of the other object.
function c_move_out(oc,ec,allowed)
 return c_push_out(ec,oc,allowed)
end

function c_push_vel(oc,ec,args)
  if (not args) args={}
  local sepv=ec.b:sepv(oc.b,args[1])  
  if not sepv then return end
  if #sepv>0.2 then sepv=sepv:norm() end
  if not ec.e.vel then return end
  if (args[2]) sepv*=args[2]
  ec.e.vel=sepv
end
-- inverse of c_push_out - moves
-- the object with the :collide()
-- method out of the other object.
function c_move_out(oc,ec,allowed)
 return c_push_out(ec,oc,allowed)
end


--------------------
-- entity handling
--------------------

entities = {}
particles = {}
old_ent = {}

function p_add(p)  
  add(particles, p)
end

function p_remove(p)
  del(particles, p)
end

function p_update()
  for p in all(particles) do
    if p.pos and p.vel then
      p.pos+=p.vel
    end
    if (p.update) p:update()

    if p.t > p.lifetime or p.done then
      p_remove(p)
    else
      p.t+=1
    end
  end
end

-- adds entity to all entries
-- of the table indexed by it's tags
function e_add(e)
  add(entities, e)

  if e.draw_order then
    if (not r_entities[e.draw_order]) r_entities[e.draw_order]={}
    add(r_entities[e.draw_order],e)
  else
    if (not r_entities[3]) r_entities[3]={}
    add(r_entities[3],e)
  end
end

function e_remove(e)
  del(entities, e)
  for tag in all(e.tags) do        
    if e.bkt then
      del(bkt_get(tag, e.bkt.x, e.bkt.y), e)
    end
  end

  if e.draw_order then    
    del(r_entities[e.draw_order],e)
  else  
    del(r_entities[3],e)
  end

  if e.destroy then e:destroy() end
end

-- loop through all entities and
-- update them based on their state
function e_update_all()  
  for e in all(entities) do
    if (slowmo and (e_is_any(e,{"player","camera","attack"}) or slowmo_update)) or 
        (not slowmo) then
      if e[e.state] then
        e[e.state](e)
      end
      if e.update then
        e:update()
      end
      e.t+=1

      if e.done then
        e_remove(e)
      end
    end
  end  
end

r_entities = {}

function e_draw_all()
  for i=0,7 do
    for e in all(r_entities[i]) do
      if debug then
        local ec=c_get_entity(e)
        if ec.b then
          rectfill(ec.b.xl,ec.b.yt,ec.b.xr,ec.b.yb,8)
        end
      end

      e:render()
    end
  end
end

function p_draw_all()
  for p in all(particles) do
    p:render()
  end
end

function spr_render(e)
  spr(e.sprite, e.pos.x, e.pos.y)
end

-------------------------------
-- helper functions
-------------------------------

function sign(val)
  return val<0 and -1 or (val > 0 and 1 or 0)
end

function frac(val)
  return val-flr(val)
end

function ceil(val)
  if (frac(val)>0) return flr(val+sign(val)*1)
  return val
end

function approach(val,target,step)
  step=abs(step)
  if val < target then
    return min(val+step,target)
  elseif val > target then
    return max(val-step,target)
  else
    return target
  end  
end

function remove_old(tags)
  for e in all(old_ent) do
    local rmv=true
    for t in all(tags) do
      if (e.is_a and e:is_a(t)) rmv=false
    end

    if (rmv) e_remove(e)
  end
  old_ent={}
end

function remove_all_but(tags)
  for e in all(entities) do
    local rmv=true
    for t in all(tags) do
      if (e:is_a(t)) rmv=false
    end

    if (rmv) e_remove(e)
  end
end

function draw_dithered(t,flip,box,c)
  local low,mid,hi=0b0000000000000000.1,
                   0b1010010110100101.1,
                   0b1111111111111111.1                
  if flip then low,hi=hi,low end

  if t <= 0.3 then
    fillp(low)
  elseif t <= 0.6 then
    fillp(mid)
  elseif t <= 1 then
    fillp(hi)
  end

  if box then
    rectfill(box.xl,box.yt,box.xr,box.yb,c or 0)
    fillp()
  end
end

function add_time(t)
  global_timer.t+=t
end

function timer_update(timer)
  timer.t-= time()-last
end

function e_is_any(e, op)
  if not e.is_a then return end
  for i in all(e.tags) do
    for o in all(op) do
      if e:is_a(o) then return true end
    end
  end

  return false
end

-------------------------------
-- init, update, draw
-------------------------------

global_timer={ t = 60 }
lights={}
enable_light=false
slowmo = true
slowmo_update=false
lightpoints={}

function _init()
  global_timer={ t = 60 }
  load_level()
  e_add(cam(
    {

    }
  ))

  last=time()

  for i=0,15 do
    for j=0,15 do
      add(lights, light({off=v(i,j)*8,pos=v(i,j)*8}))
    end
  end
end

function _update()
  e_update_all()
  bkt_update()
  do_movement()
  do_collisions()
  p_update()

  if not slowmo or (slowmo and slowmo_update) then
    timer_update(global_timer)
  end

  slowmo_update=not slowmo_update
  last=time()

  if btnp(4) then slowmo=not slowmo end
end

function _draw()
  cls()

  if slowmo then
    pal(0,7)
    pal(7,0)
  end
  rectfill(0,0,128,128,0)
  palt(0, false)
  palt(1, true)
  e_draw_all()
  p_draw_all()
  palt()
  pal()

  if enable_light then
    for l in all(lights) do
      l:render()
    end
  end

  camera()

  rectfill(1,1,13,11,0)
  rect(1,1,13,11,7)
  print(flr(global_timer.t),4,4,7)

  if debug then
  local cpu,mem=flr(100*stat(1)),flr(stat(0))
  print("cpu: " .. cpu .. " mem: " .. mem .. " ent: " .. #entities, 1, 0, 0)
  print("cpu: " .. cpu .. " mem: " .. mem .. " ent: " .. #entities, 2, 1, 0)
  print("cpu: " .. cpu .. " mem: " .. mem .. " ent: " .. #entities, 0, 1, 0)
  print("cpu: " .. cpu .. " mem: " .. mem .. " ent: " .. #entities, 1, 2, 0)
  print("cpu: " .. cpu .. " mem: " .. mem .. " ent: " .. #entities, 1, 1, 14)  
  end
end
__gfx__
00000000000000001007770111111111110700110000000007777770111111111111111111111111007777000000000000000000000000000000000000000000
00000000000770001077070110001111110770110777777070000007111111111111111111111111070000700000000000000000000000000000000000000000
00000000007007001077770100700000110770117000000770000007111111111111111111000011700000070000000000000000000000000000000000000000
07770000070990701000000177777777110770117007700700000000100000011111111110099001707007070000000000000000000000000000000000000000
07077777007007000077770070777770100770017770077777700777009999000000000000900900700000070000000000000000000000000000000000000000
07770707070770700700007000700000107777017007700770077007090000900999999009000090700000070000000000000000000000000000000000000000
00000000700000070001100010001111100700017000000770000007090000909000000909099090070000700000000000000000000000000000000000000000
00000000077777701111111111111111110770117777777777777777009999000999999000900900007777000000000000000000000000000000000000000000
11000001111111111100000199999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10077701110000011007770100909099999990900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10777701100777011077770199999009009090990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10770701107777011077070100099099999990090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10777700107707011077770100009090000990990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000077107777001000000099999099999990900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
17777007177770771777707790000009900000990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
17007007170070071700700799999999999999990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11000001100777011100000110077701110000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10077701107070011007770110777001100777010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10770701107777011077070110777701107707010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10777701100000011077770110000001107777010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000001007777001000000100777700100000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10777701070000701077770107000070107777010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10700701000110001007700100011000100770010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000001111111111100001111111111110000110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aa000007777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a00a00070000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000a0700700070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000a0700700070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a00a00700070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00066000700007070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000070000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00066000007777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007700000777077700077000000077777700077770000000077777700000000000000000000000000000000000077007700000000000000000000000
07007000070770700777077700700700077700000077700007770077070000707777777777777777077777777777777000077770777000000000000000000000
70700007707707700000000000777700700000000000000000007707070000707000000000000007070000000000007000077007000770000000000000000000
07000000770000007077707700707700700000000000000000000007070000707000000000000007070000000000007007777000700007700000000000000000
00000700000007007077707700707700070000000000000000000007070000707000000000000007070000000000007007070007000000700000000000000000
00007070077070700000000000770700070000000000000000000070070000707000000000000007070000000000007007007000700000700000000000000000
07000700707077700777077700770700070000000000000000000070070000707777777777777777070000777700007007000007000000700000000000000000
00000000770007700777077700777700070000000000000000000070070000700700070007000700070000700700007007000007700000700000000000000000
00000000077077707770777000777700070000000000000000000070070000700000000007000070070000700700007007000770077000700000000000000000
00000700777077700000000000707700700000000000000000000070070000707777777707000070070000777700007007077000000770700000000000000000
00000000770077000777077700777700700000000000000000000007070000700000000007000070070000000000007007700000000007700000000000000000
00700000000777000777077700770700700000000000000000000007070000700000000007000070070000000000007000707770077707000000000000000000
00000000770000000000000000770700700000000000000000000007070000700000000007000070070000000000007000707070070707000000000000000000
00000000777077707770777000770700070000000000000000000070070000700000000007000070070000000000007000707070077707000000000000000000
70007700777077007770777000777700070000000000000000000070070000707777777707000070077777777777777000707070000007000000000000000000
70000000000000000000000000777700070000000000000000000070077777700700070007000070070007000700007000777777777777000000000000000000
00000000000000000770077000777700700000000000000000000007070070700700070000000000070007000700007000000000000000000000000000000000
00000077770000007000700700707070700000000000000000000007077777707777777700000000077777777777777000007000000000000000000000000000
00077700007770007007000700777070700000000000000000000007070700700070007007770000070000700070007000000000000000000000000000000000
00770707007077000070007000707070070000000000000000000070077777700070007007077777070000700070007000000070000000000000000000000000
07007000000700700770070000707700070000000000000000000070070070707777777707770707077777777777777000000000000000000000000000000000
70700070070007077007700700777700007000000000000000000007077777707000700000000000070070007000707000007000000000000000000000000000
77007700007700777007000707777770000777000007777700007770070707007000700000000000070070007000707000000000000000000000000000000000
70007000000700700770077077707077000000777770000077770000007070707777777700000000077777777777777000000070000000000000000000000000
07000070700000701111111100000000070007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70707007000707071111111107000700077077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77070700707070770000000107000700077077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777707707777000770070100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00070077770070007007770100000000007000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700007007000700070100700070007707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07077070070770700077700100700070007707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07770007700077701000001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000010000000000000002020200000000000000000000000000020202000000000000000000000000000200020000000000000000000000000000000001030003010301030303030303030202010300030300030303030303030302020303020301030101010001010100020203030000000000000000000000000002
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
6061535353536061535360615353536061535360615353606153536061535353515151515151515151515151515151510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7071636353637071535370716353637071635370716363707153637071635353513000000051515151515151515151510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6061004163000000636300000063000000006300000007000063000000006347510000000051515151001313005151510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7071000000000000000000000000500000000000004041404100000000000059510000005151515100005151005151510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6061000000000000000000000000000000000000004141414100004c4d500059515100005151000000000051000051510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7071410000007200001300000000000000000000004140414000005c5d050059515151001300005151510013000051510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6061000000004300000000000000000000000000000000000000106c6d000057515151515151005151515151510051510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7071000000005300000000620000000000000000000000000000000000070067515151515151005151515151000051510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6061410000006300200000000000000000005000000000000000000000000000000051515113005151515151005151510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7071000000000000000000010000000000000000000000000000000000000000000000000000515151515151005151510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6061000000000000000000000000000000000000000000000000000000000047515151515173515151515151000051510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7071004100000000400000000000500000000000000050000000000040000059515151515173730051515151510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60610000000000000000004100000000000000000000000000000a0000000059515151515151510051510000000051510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7071410043410000410043000000000000000043000000430000000000004359515151515151510000510051515151510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6061606153436061434353606160616061606153436061536061434360615359515151515151515100130051515151510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7071707153537071535353707170717071707153537071537071535370715359515151515151515151515151515151510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000053530000535353000000000000535353535353535353535353535357000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000063630000636363000000000000636363636363636363636363636367000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
