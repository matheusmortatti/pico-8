pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
------------------------------------
-- template
------------------------------------

------------------------------------
-- base objects
------------------------------------

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

function entity:draw_dit(ct,ft,flp)
  draw_dithered(
   ct/ft,
   flp,
   box(self.pos.x+self.hitbox.xl,
   self.pos.y+self.hitbox.yt,
   self.pos.x+self.hitbox.xr,
   self.pos.y+self.hitbox.yb)
   )
end


------------------------------------
-- dynamic objects
------------------------------------

dynamic=entity:extend({
    maxvel=1,
    acc=0.5,
    fric=0.5,
    vel=v(0,0),
    hit=false,
    c_tile=true,
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

------------------------------------
-- collision boxes
------------------------------------

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


------------------------------------
-- particles
--    common class for all
--    particles
-- implements init(), update() and
-- render()
------------------------------------

particle=object:extend(
  {
    t=0,vel=v(0,0),
    lifetime=30
  }
)

------------------------------------
-- bucket / collisions
------------------------------------

c_bucket = {}

function do_movement()
  for e in all(entities) do
      if e.vel then
        for i=1,2 do
          e.pos.x+=e.vel.x/2
          collide_tile(e)
          
          e.pos.y+=e.vel.y/2
          collide_tile(e)
        end
      end
    end
end

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

------------------------------------
-- tile collision
------------------------------------

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
      allowed[i]= not is_solid(np.x,np.y) and not (np.x < 0 or np.x > 127 or np.y < 0 or np.y > 63)
    end

    c_push_out(oc, ec, allowed)
    if (ec.e.tcollide) ec.e:tcollide()    
  end
end

-- get entity with the right position
-- for cboxes
function c_get_entity(e)
  local ec={e=e,b=e.hitbox}
  if (ec.b) ec.b=ec.b:translate(e.pos)
  return ec
end

function tile_at(cel_x, cel_y)
	return mget(cel_x, cel_y)
end

function is_solid(cel_x,cel_y)
  return fget(mget(cel_x, cel_y),1)
end

function solid_at(x, y, w, h)
	return #tile_flag_at(box(x,y,x+w,y+h), 1)>0
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
 return sepv
 end
-- inverse of c_push_out - moves
-- the object with the :collide()
-- method out of the other object.
-- function c_move_out(oc,ec,allowed)
--  return c_push_out(ec,oc,allowed)
-- end

------------------------------------
-- entity handling
------------------------------------

entities = {}
particles = {}
r_entities = {}

function update_draw_order(e, ndr)
    e.draw_order = e.draw_order or 3
    del(r_entities[e.draw_order], e)

    e.draw_order = ndr or 3
    add(r_entities[e.draw_order], e)
end

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

    if (p.t > p.lifetime or p.done)p_remove(p)
    p.t+=1
  end
end

function e_find_tag(t)
  for e in all(entities) do
    if(e:is_a(t)) return e
  end

  return nil
end

-- adds entity to all entries
-- of the table indexed by it's tags
function e_add(e)
  add(entities, e)

  local dr=e.draw_order or 3
  if (not r_entities[dr]) r_entities[dr]={}
  add(r_entities[dr],e)
end

function e_remove(e)
  del(entities, e)
  for tag in all(e.tags) do        
    if e.bkt then
      del(bkt_get(tag, e.bkt.x, e.bkt.y), e)
    end
  end

  del(r_entities[e.draw_order or 3],e)

  if e.destroy then e:destroy() end
end

-- loop through all entities and
-- update them based on their state
function e_update_all()  
  for e in all(entities) do
    if (e[e.state])e[e.state](e)
    if (e.update)e:update()
    e.t+=1

    if e.done then
      e_remove(e)
    end
  end
end

function e_draw_all()
  for i=0,7 do
    for e in all(r_entities[i]) do
      if (e.render)e:render()
      if debug and e.hitbox then 
        rect(e.pos.x + e.hitbox.xl, 
             e.pos.y + e.hitbox.yt, 
             e.pos.x + e.hitbox.xr, 
             e.pos.y + e.hitbox.yb, 8)
      end
    end
  end
end

function p_draw_all()
  for p in all(particles) do
    p:render()
  end
end

function spr_render(e)
  spr(e.sprite, e.pos.x, e.pos.y,1,1)
end

------------------------------------
-- utils
------------------------------------

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
  return val < target and min(val+step,target) or max(val-step,target)
end

function clamp(low, hi, val)
	return (val < low) and low or (val > hi and hi or val)
end

function choose(arg)
    return arg[flr(rnd(#arg)) + 1]
end

function draw_dithered(t,flp,box,c)
  local low,md,hi=0b0000000000000000.1,
                   0b1010010110100101.1,
                   0b1111111111111111.1                
  if flp then low,hi=hi,low end

  if t <= 0.3 then
    fillp(low)
  elseif t <= 0.6 then
    fillp(md)
  elseif t <= 1 then
    fillp(hi)
  end

  if box then
    rectfill(box.xl,box.yt,box.xr,box.yb,c or 0)
    fillp()
  end
end


function e_is_any(e, op)
  for i in all(e.tags) do
    for o in all(op) do
      if e:is_a(o) then return true end
    end
  end

  return false
end

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

------------------------------------
-- boilerplate code
------------------------------------

state = nil

-- destroys everything from current state
function reset_state()

end

function change_state(new_state)
    state = new_state

    -- destroy everything
    reset_state()

    state.init()
end

function _init()
    change_state(gamestate)
end

function _update()
    state.update()
end

function _draw()
    state.draw()
end
-->8
------------------------------------
-- game state + globals
------------------------------------

debug=false
global_timer = 60
gamestate = {}

function gamestate.init()
	load_level()
 e_add(cam(
   {

   }
 ))
 
 palt(0, false)
 palt(1, true)
end

function gamestate.update()
 e_update_all()
 bkt_update()
 do_movement()
 do_collisions()
 p_update()
end

function gamestate.draw()
 cls()

 e_draw_all()
 p_draw_all()
end


-->8
-------------------------------
-- structural
-------------------------------

function add_time(t)
	global_timer += t
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

-------------------------------
-- level loading
-------------------------------

function is_in_level(a, b)
  local ma,mb=a.pos/128,b.pos/128
  ma.x=flr(ma.x)
  ma.y=flr(ma.y)
  mb.x=flr(mb.x)
  mb.y=flr(mb.y)

  return ma==mb
end

current_level = nil
level_index=v(4,1)

function load_level()
 old_ent=shallow_copy(entities)
 current_level = level({
   base=v(level_index.x*16,level_index.y*16),
   pos=v(level_index.x*128,level_index.y*128),
   size=v(16,16)
 })
 e_add(current_level)
end

level=entity:extend({
 draw_order=1
})

function level:init()
 -- start with a lit area. any light_switches will make the room dark
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
    remove_old({"player","camera","key", "gate","pedestal"})
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
-->8
-------------------------------
-- particles
-------------------------------

-------------------------------
-- smoke particle
-------------------------------

smoke=particle:extend(
  {
    vel=v(0,0),
    c=7,
    v=0.1
  }
)

function smoke:init()
  self.vel=v(rnd(0.5)-0.25,-(rnd(1)+0.5))
  if not self.r then self.r=rnd(1)+1.5 end
end

function smoke:update()
  self.r-=self.v
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

  --rectfill(self.pos.x,self.pos.y,self.pos.x+4*#self.txt+2,self.pos.y+4,0)

  print(self.txt,self.pos.x-1,self.pos.y,0)
  print(self.txt,self.pos.x+1,self.pos.y,0)
  print(self.txt,self.pos.x,self.pos.y-1,0)
  print(self.txt,self.pos.x,self.pos.y+1,0)
  print(self.txt,self.pos.x+1,self.pos.y+1,0)
  print(self.txt,self.pos.x+1,self.pos.y-1,0)
  print(self.txt,self.pos.x-1,self.pos.y+1,0)
  print(self.txt,self.pos.x-1,self.pos.y-1,0)
  print(self.txt,self.pos.x,self.pos.y,self.c or 7)

  if self.t > 2*self.lifetime/3 then
    draw_dithered(
      (self.lifetime-self.t)/(2*self.lifetime/3),false,
      box(self.pos.x,self.pos.y,self.pos.x+4*#self.txt+2,self.pos.y+4))
  end
end
-->8
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
 lr=32
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
 if e:is_a("slowdown") then
  self.maxvel=self.basevel/2
 end
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
 dmg=1,
 sprite=3,
 draw_order=5
})

function sword_attack:init()
 if self.upg then
  for i=1,4 do
   e_add(smoke({
    pos=v(self.pos.x+rnd(8),self.pos.y+rnd(8)),
    vel=v(rnd(0.5)-0.25,-(rnd(1)+0.5)),
    c=rnd(1)<0.7 and 12 or 7,
    v=0.15
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
-- entity: old man
-------------------------------

old_man=dynamic:extend({
 collides_with={"player"},
 tags={"old_man"}, dir=v(1,0),
 hitbox=box(-3,3,11,12),
 sprite=0,
 draw_order=3,
 ssize=3,
 inv_sp=30,
 is_talking=false,
 cursor=0,
 tspd=3,
 line='oier come que\nce ta? bom ?',
 base_offset = 6,
 offset = 0,
 p=nil,
 line_size=0
})

old_man:spawns_from(2)

function old_man:update()
  if (not self.p) self.cursor=0 self.offset=0 self.line_size=0 return
  self.p=nil

  if (self.cursor >= #self.line) return

  if self.t%self.tspd == 0 then
    self.cursor += 1
    
    self.line_size = max(self.cursor/(self.offset+1)-1, self.line_size)
    if sub(self.line, self.cursor, self.cursor) == '\n' then
      self.offset += 1
    end
  end
end

function old_man:collide(e)
  self.p=e
end

function old_man:render()
 local s=0
 s=s+flr(self.ssize*(self.t%self.inv_sp)/self.inv_sp)
 spr(s,self.pos.x, self.pos.y)

 local x,y=self.pos.x-10,self.pos.y-5-self.base_offset*self.offset
 if (self.cursor ~= 0) rectfill(x, y-1, x+4*self.line_size, y+6*(self.offset+1), 0)
 print(sub(self.line, 0, self.cursor), x, y, 7)
end

-------------------------------
-- entity: light system
-------------------------------

lightpoints = {}

light_system=entity:extend({
 tags={"light_system"},
 draw_order=7,
 tpos = nil,
 ppos = nil,
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
        if r~=nil then
          local dist = v(
            abs(e.pos.x-(self.ppos.x+i*16)),
            abs(e.pos.y-(self.ppos.y+j*16))
          ):len()

          if dist < r then
            ll=3
          elseif dist < (r+16) and ll<2 then
            ll=2
          end
        end
      end
      self.rects[i*16+j] = {self.ppos.x+i*16,self.ppos.y+j*16,ll}
    end
  end
end

function light_system:render()
  for i=1,16*16 do
    local v=self.rects[i-1]
    local x,y,ll=v[1],v[2],v[3]
    fillp(self.pt[ll])
    rectfill(x,y,x+16,y+16,0)
    fillp()
  end
end

-------------------------------
-- entity: pedestal
-------------------------------

pedestal=entity:extend({
  tags={"pedestal"},
  draw_order=1,
})

pedestal:spawns_from(78)

function pedestal:init()
  mset(self.map_pos.x,self.map_pos.y,0)
  e_add(key({
     pos=v(self.pos.x+4,self.pos.y-2),
     map_pos=self.map_pos
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
 c_tile=false
})

function key:init()
  self.original_pos = self.pos
  self:become("idle")
end

function key:follow()
  local g = e_find_tag("gate")
  if (g~=nil and is_in_level(self, g)) self.p=g

  local v=self.p.pos-self.pos
  self.dir=v:norm()
  self.vel=self.dir*(v:len()-4)*self.spd
end

function key:render()
  if self.state == "idle" then
    spr(
      self.sprite, 
      self.original_pos.x, 
      self.original_pos.y + self.amp*sin(self.t*self.scl))
  else
    self.render=spr_render
  end
end

function key:collide(e)
  if (self.state=="idle") self.p=e self:become("follow")
  if e:is_a("gate") then
   self.done=true
   shake=5
   for i=1,2 do
    e_add(smoke({
      pos=v(self.pos.x+rnd(8),self.pos.y+rnd(8)),
      vel=v(rnd(0.5)-0.25,-(rnd(1)+0.5)),
      c=rnd(1)<0.7 and 6 or 7,
      v=0.15
    }))
   end
  elseif e:is_a("key") then
    return c_push_out
  end
end

-------------------------------
-- entity: gate
-------------------------------

gate=entity:extend({
  hitbox=box(0,0,16,16),
  collides_with={"key", "player"},
  tags={"gate"},
  kspr=13,
  kcount=3,
})

gate:spawns_from(11)

function gate:init() mset(self.map_pos.x,self.map_pos.y,0) end

function gate:dead()
  if (self.t==60) self.done=true
  if self.t%4 then
    local p=self.pos+v(2+rnd(12), 2+rnd(12))
    for i=1,2 do
      e_add(smoke({
        pos=v(p.x+rnd(4), p.y+rnd(4)),
        vel=v(rnd(0.5)-0.25,-(rnd(1)+0.5)),
        c=rnd(1)<0.7 and 6 or 7,
        v=0.15
      }))
    end
    shake=3
  end
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
  if (e:is_a("player")) return c_push_out
  self.kcount-=1
  if(self.kcount==0) self:become("dead")
end

-->8
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
  spr(s,self.pos.x,self.pos.y)

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
  attack_dist=60,
  vel=v(0,0),
  maxvel=0.5,  
  fric=0.1,
  acc=2,
  health=2,
  c_tile=false
})

bat:spawns_from(55)

function bat:init()
  self.orig = v(self.pos.x, self.pos.y)
end

function bat:idle()
  if not scene_player then return end
  local dist=sqrt(#v(scene_player.pos.x-self.pos.x,
             scene_player.pos.y-self.pos.y))
  if dist < self.attack_dist then 
    self:become("attacking")
    self.sprite=53
    self.ssize=2
    self.svel=0.05
  end
end

function bat:attacking()
  if not scene_player then return end

  self.dir=v(scene_player.pos.x-self.pos.x,
             scene_player.pos.y-self.pos.y):norm()  

  self:set_vel()

  self.pos += v(0, 0.5*sin(self.t/40+0.5))
end
__gfx__
11000001111111111100000111111111110700110000000007777770111111111111111111111111007777000000000000000000111111110000000000000000
10077701110000011007770110001111110770110777777070000007111111111111111111111111070000700000007777000000110000110000000000000000
10777701100777011077770100700000110770117000000770000007111111111111111111000011700000070000777007770000100770010000000000000000
10770701107777011077070177777777110770117007700700000000100000011111111110099001707007070007007007007000107007010000000000000000
10777700107707011077770170777770100770017770077777700777009999000000000000900900700000070077007007007700100700010000000000000000
10000077107777001000000000700000107777017007700770077007090000900999999009000090700000070707007007007070110770110000000000000000
17777007177770771777707710001111100700017000000770000007090000909000000909099090070000707007007007007007110000110000000000000000
17007007170070071700700711111111110770117777777777777777009999000999999000900900007777007007007007007007111111110000000000000000
11111111007777000000000099999000000000000000000000000000000000000000000000000000000000007007007007007007000000000000000000000000
11111111070000700000000000909099999990900000000000000000000000000000000000000000000000007007007007007007000000000000000000000000
00000111007777000077700099999009009090990000000000000000000000000000000000000000000000007007007007007007000000000000000000000000
07770000070000700700007000099099999990090000000000000000000000000000000000000000000000007007007007007007007000000000000000000000
07077777777777777700777700009090000990990000000000000000000000000000000000000000000000007007007007007007000000000000000000000000
07770707777777777777077799999099999990900000000000000000000000000000000000000000000000007007007007007007000000000000000000000000
00000000077777700077777090000009900000990000000000000000000000000000000000000000000000007007007007007007000000000000000000000000
11111111007777000000000099999999999999990000000000000000000000000000000000000000000000007777777777777777000000000000000000000000
11000001100777011100000110077701110000011111111111111111111111111111111100000000000000000000000000000000000000000000000000000000
10077701107070011007770110777001100777011100000111100000111000011111111100000000000000000000000000000000000000000000000000000000
10770701107777011077070110777701107707011007770111007770000077001000000000000000000000000000000000000000000000000000000000000000
10777701100000011077770110000001107777011077070111077070077077700077077000000000000000000000000000000000000000000000000000000000
10000001007777001000000100777700100000011077770111077770007070700007077700000000000000000000000000000000000000000000000000000000
10777701070000701077770107000070107777011000000100000000007077700007077700000000000000000000000000000000000000000000000000000000
10700701000110001007700100011000100770011077770100777701077000000077077700000000000000000000000000000000000000000000000000000000
10000001111111111100001111111111110000111000000100000001000011110000000000000000000000000000000000000000000000000000000000000000
000aa000007777000000000011111111111111111000100011111111110707010077000000000000000000000000000000000000000000000000000000000000
00a00a00070000700007770000000111111111110070007011100011100797007700770000000000000000000000000000000000000000000000000000000000
0a0000a0700700070070007099990011100001110700900710009000107707700000000000000000000000000000000000000000000000000000000000000000
0a0000a0700700070007770090909001009900010779097700790970100090000077007700000000000000000000000000000000000000000000000000000000
00a00a00700070070070007090090900090999000700900707709077111000110000770000000000000000000000000000000000000000000000000000000000
00066000700007070777777709907770900977700000000000700070111111117700000000000000000000000000000000000000000000000000000000000000
00077000070000700077777007000007999000071111111110000000111111110077700700000000000000000000000000000000000000000000000000000000
00066000007777000007770000777770007777701111111111111111111111110000000000000000000000000000000000000000000000000000000000000000
00000000007700000077000000077000000077777700077770000000077777700000000000000000000000000000000000077007700000007777777777777777
07007000070770707707700000700700077700000077700007770077070000707777777777777777077777777777777000077770777000007700000000000077
70700007707707700770000000777700700000000000000000007707070000707000000000000007070000000000007000077007000770007077777777777707
07000000770000000000000000707700700000000000000000000007070000707000000000000007070000000000007007777000700007707070000000000707
00000700000007000000770000707700070000000000000000000007070000707000000000000007070000000000007007070007000000707070000000000707
00007070077070700007700700770700070000000000000000000070070000707000000000000007070000000000007007007000700000707070000770000707
07000700707077700000707000770700070000000000000000000070070000707777777777777777070000777700007007000007000000707070070000700707
00000000770007700000000000777700070000000000000000000070070000700700070007000700070000700700007007000007700000707070070000700707
00000000077077700777000000777700070000000000000000000070070000700000000007000070070000700700007007000770077000707070000770000707
00000700777077707777700000707700700000000000000000000070070000707777777707000070070000777700007007077000000770707070000000000707
00000000770077000777000000777700700000000000000000000007070000700000000007000070070000000000007007700000000007707070000000000707
00700000000777000000000000770700700000000000000000000007070000700000000007000070070000000000007000707770077707007070777777770707
00000000770000000000777000770700700000000000000000000007070000700000000007000070070000000000007000707070070707007077700000077707
00000000777077700007777700770700070000000000000000000070070000700000000007000070070000000000007000707070077707007700777777770077
70007700777077000000777000777700070000000000000000000070070000707777777707000070077777777777777000707070000007000000700000070000
70000000000000000000000000777700070000000000000000000070077777700700070007000070070007000700007000777777777777000000777777770000
00000000000000000770077000777700700000000000000000000007070070700700070000000000070007000700007000000000000000000000000000000000
00000077770000007000700700707070700000000000000000000007077777707777777700000000077777777777777000007000000000000000000000000000
00077700007770007007000700777070700000000000000000000007070700700070007007770000070000700070007000000000000000000000000000000000
00770707007077000070007000707070070000000000000000000070077777700070007007077777070000700070007000000070000000000000000000000000
07007000000700700770070000707700070000000000000000000070070070707777777707770707077777777777777000000000000000000000000000000000
70700070070007077007700700777700007000000000000000000007077777707000700000000000070070007000707000007000000000000000000000000000
77007700007700777007000707777770000777000007777700007770070707007000700000000000070070007000707000000000000000000000000000000000
70007000000700700770077077707077000000777770000077770000007070707777777700000000077777777777777000000070000000000000000000000000
07000070700000701111111100000000070007000770770000000000000000000000000000000000000000000000000000000000000000000000000000000000
70707007000707071111111107000700077077007770077000000900000000000000000000000000000000000000000000000000000000000000000000000000
77070700707070770000000107000700077077007707707009009090000000000000000000000000000000000000000000000000000000000000000000000000
00777707707777000770070100000000000000000077000090900900000000000000000000000000000000000000000000000000000000000000000000000000
00070077770070007007770100000000007000707070077009000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700007007000700070100700070007707707700777000000700000000000000000000000000000000000000000000000000000000000000000000000000
07077070070770700077700100700070007707700770770007000000000000000000000000000000000000000000000000000000000000000000000000000000
07770007700077701000001100000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000
57575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757
57575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757
57575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757
57575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757
57575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57000000000000000000000000000057570000000000000000000000000000575700000000000000000000000000005757000000000000000000000000000057
57575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757
57575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757
__label__
07707700077077000770770007707700077077000770770007707700077077000770770007707700077077000770770007707700077077000770770007707700
77700770777007707770077077700770777007707770077077700770777007707770077077700770777007707770077077700770777007707770077077700770
77077070770770707707707077077070770770707707707077077070770770707707707077077070770770707707707077077070770770707707707077077070
00770000007700000077000000770000007700000077000000770000007700000077000000770000007700000077000000770000007700000077000000770000
70700770707007707070077070700770707007707070077070700770707007707070077070700770707007707070077070700770707007707070077070700770
77007770770077707700777077007770770077707700777077007770770077707700777077007770770077707700777077007770770077707700777077007770
07707700077077000770770007707700077077000770770007707700077077000770770007707700077077000770770007707700077077000770770007707700
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000000000009000000000000000000000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000000990000000000000000000000000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000000999000000000000000000000000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000000090000000000000000000000000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000000099000000000000000000000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000009900000000000000000000000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000009990000000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000000990700000000000000000000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000000000000000000000000700070000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000000900000000000000007009007000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000009990000000000000007790977000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000000999000000000000007009007000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000009997000000000000000000000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000007779000000000000000000000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000077777700000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000777777070000000099999090000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000777777070000000000909099000000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000007770700000000099999009000000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000077007000000000000099099000000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000700770070000000099999090000000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000700700070000000090000099000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000077007700000000099999999000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000000000000000007770000000000000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000000000000000000777000000000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000000000000000007777000000000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000000000000000007777000000000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000000000000000070000700000000000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
77700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077700770
77077070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077077070
00770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000
70700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070700770
77007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077007770
07707700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007707700
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07707700077077000770770007707700077077000770770007707700077077000770770007707700077077000770770007707700077077000770770007707700
77700770777007707770077077700770777007707770077077700770777007707770077077700770777007707770077077700770777007707770077077700770
77077070770770707707707077077070770770707707707077077070770770707707707077077070770770707707707077077070770770707707707077077070
00770000007700000077000000770000007700000077000000770000007700000077000000770000007700000077000000770000007700000077000000770000
70700770707007707070077070700770707007707070077070700770707007707070077070700770707007707070077070700770707007707070077070700770
77007770770077707700777077007770770077707700777077007770770077707700777077007770770077707700777077007770770077707700777077007770
07707700077077000770770007707700077077000770770007707700077077000770770007707700077077000770770007707700077077000770770007707700
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000757400000000000000000000000000000001030101010101030303030303030101010301010101010303030303030301010303030101010103030003030101010103030101010301010101010101010101
0101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101017501010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
7575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757500007575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575
757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575750b0c7575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575
750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075755151510000000000000000000030757500000000001b1c0000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757551515100000000000000000000007575000000000000000000606100000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075755151510000000000000000000000757500004c4d0000000000707100000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500005c5d0000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500006c020000000000004000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000004e4f0000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000005e5f0000000000000000000000000000200000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000000052420000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000000000000000000000620013000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000500000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000060610000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500506d000000007670717600000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000400000020076760000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075750000000000000000000000000000757500000000000000000000000000007575000000000000000000000000000075
7575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575757575
