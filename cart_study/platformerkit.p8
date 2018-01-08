pico-8 cartridge // http://www.pico-8.com
version 14
__lua__
-------------------------------
-- helper functions
-------------------------------

-- creates a deep copy of a
-- table and all its properties
function deep_copy(obj)
 if (type(obj)~="table") return obj
 local cpy={}
 setmetatable(cpy,getmetatable(obj))
 for k,v in pairs(obj) do
  cpy[k]=deep_copy(v)
 end
 return cpy
end

-- adds an element to an index,
-- creating a new table in the
-- index if needed
function index_add(idx,prop,elem)
 if (not idx[prop]) idx[prop]={}
 add(idx[prop],elem)
end

-- calls a method on an object,
-- if it exists
function event(e,evt,p1,p2)
 local fn=e[evt]
 if fn then
  return fn(e,p1,p2)
 end
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

-- round to nearest whole number
function round(x)
 return flr(x+0.5)
end

-------------------------------
-- objects and classes
-------------------------------

-- "object" is the base class
-- for all other classes
-- new classes are declared
-- by using object:extend({...})
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

-------------------------------
-- vectors
-------------------------------

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
-- entities
-------------------------------

-- every entity has some
-- basic properties
-- entities have an embedded
-- state that control how
-- they display and how they
-- update each frame
-- if entity is in state "xx",
-- its method "xx" will be called
-- each frame
entity=object:extend({
 state="idle",t=0,
 dynamic=true,
 spawns={}
})
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

-- static entities never move
-- like the level's walls -
-- this lets us optimize a bit,
-- especially for collision
-- detection.
static=entity:extend({
 dynamic=false
})

-------------------------------
-- rendering from the "sprite"
-- property
-------------------------------

function spr_render(e)
 local s,p=e.sprite,e.pos
 -- helper function for
 -- retrieving sprite data
 -- taking entity state into
 -- account, or a default value
 function s_get(prop,dflt)
  local st=s[e.state]
  if (st~=nil and st[prop]~=nil) return st[prop]
  if (s[prop]~=nil) return s[prop]
  return dflt
 end
 -- sprite position
 local sp=p+s_get("offset",v(0,0))
 -- width and height
 local w,h=
  s.width or 1,s.height or 1
 -- orientation
 local flip_x=false
 local frames=s[e.state] or s.idle
 if s.turns then
  if e.facing=="up" then
   frames=frames.u
  elseif e.facing=="down" then
   frames=frames.d
  else
   frames=frames.r
  end
  flip_x=(e.facing=="left")
 end
 if s_get("flips") then
  flip_x=e.flipped
 end
 -- animation
 local delay=frames.delay or 1
 if (type(frames)~="table") frames={frames}
 local frm_index=flr(e.t/delay) % #frames + 1
 local frm=frames[frm_index]
 -- actual drawing
 spr(frm,round(sp.x),round(sp.y),w,h,flip_x)
 -- the current animation frame
 -- is returned, useful for
 -- custom :render() methods
 return frm_index
end

-------------------------------
-- entity registry
-------------------------------

-- entities are indexed for
-- easy access.
-- "entities" is a table with
-- all active entities.
-- "entities_with.<property>"
-- holds all entities that
-- have that property (used by
-- various systems to find
-- entities that move, collide,
-- etc.)
-- "entities_tagged.<tag>"
-- holds all entities with a
-- given tag, and is used for
-- collisions, among other
-- things.

-- resets the entity registry
function entity_reset()
 entities,entities_with,
  entities_tagged={},{},{}
end

-- registers a new entity,
-- making it appear in all
-- indices and update each
-- frame
function e_add(e)
 add(entities,e)
 for p in all(indexed_properties) do
  if (e[p]) index_add(entities_with,p,e)
 end
 if e.tags then
  for t in all(e.tags) do
   index_add(entities_tagged,t,e)
  end
  c_update_bucket(e)
 end
 return e
end

-- removes an entity,
-- effectively making it
-- disappear
function e_remove(e)
 del(entities,e)
 for p in all(indexed_properties) do
  if (e[p]) del(entities_with[p],e)
 end
 if e.tags then
  for t in all(e.tags) do
   del(entities_with[t],e)
   if e.bkt then
    del(c_bucket(t,e.bkt.x,e.bkt.y),e)
   end
  end
 end
 e.bkt=nil
end

-- a list of properties that
-- need an "entities_with"
-- index
indexed_properties={
 "dynamic",
  -- entites that should update
  -- each frame
 "render","render_hud",
  -- entities that render
  -- themselves or a hud
 "vel",
  -- entities that move
  -- (have a velocity)
 "collides_with", 
  -- entities that actively
  -- check for collisions
 "feetbox"
  -- entities that can be
  -- supported by a floor
}

-------------------------------
-- system:
--  entity updating
-------------------------------

-- updates all entities
-- according to their state
function e_update_all()
 for ent in all(entities_with.dynamic) do
  -- call the method with the
  -- name corresponding to
  -- this entity's current
  -- state
  local state=ent.state
  if ent[state] then
   ent[state](ent,ent.t)
  end
  if ent.done then
   -- removed
   e_remove(ent)
  elseif state~=ent.state then
   -- changed state, restart
   -- the "t" counter that
   -- tracks how much time
   -- an entity has spent
   -- in its current state
   ent.t=0
  else
   ent.t+=1
  end  
 end
end

-- schedules a function to be
-- called between udpates -
-- needed for e.g. level
-- changes that reset the
-- entity indexes
function schedule(fn)
 scheduled=fn
end

-------------------------------
-- system:
--  rendering the world
-------------------------------

function r_render_all(prop)
 -- collect all drawables
 -- and sort them into buckets
 -- separated by draw_order
 local drawables={}
 for ent in all(entities_with[prop]) do
  local order=ent.draw_order or 0
  if not drawables[order] then
   drawables[order]={}
  end
  add(drawables[order],ent)  
 end
 -- render the drawable
 -- entities in the right
 -- order (z-indexing)
 for o=0,15 do  
  for ent in all(drawables[o]) do
   r_reset(prop)
   ent[prop](ent,ent.pos)
  end
 end
end

-- helper function that resets
-- pico-8 draw state before
-- each entity
function r_reset(prop)
 pal()
 palt(0,false)
 palt(3,true)
 if (prop~="render_hud" and g_cam) g_cam:apply()
end

-------------------------------
-- system:
--  movement
-------------------------------

function do_movement()
 for ent in all(entities_with.vel) do
  -- entities that have velocity
  -- move by that much each frame
  local ev=ent.vel
  ent.pos+=ev
  -- orientation:
  -- flipped tracks left/right
  -- 'true' is facing left
  if ev.x~=0 then
   ent.flipped=ev.x<0
  end
  -- facing:
  -- 4-direction facing, has
  -- a string value "right"/
  -- "left"/"up"/"down"
  if ev.x~=0 and abs(ev.x)>abs(ev.y) then
   ent.facing=
    ev.x>0 and "right" or "left"
  elseif ev.y~=0 then
   ent.facing=
    ev.y>0 and "down" or "up"
  end
  -- gravity affects velocity
  -- for all entities
  -- define a "weight" property
  if (ent.weight) then
   local w=state_dependent(ent,"weight")
   ent.vel+=v(0,w)
  end
 end
end

-------------------------------
-- system:
--  collision detection
-------------------------------

-- for efficiency, objects
-- requiring collisions are
-- sorted into 16x16 buckets
-- based on their position

-- find bucket coordinates
-- for entity "e"
function c_bkt_coords(e)
 local p=e.pos
 return flr(shr(p.x,4)),flr(shr(p.y,4))
end

-- get the bucket of entities
-- with tag "t" at coords x,y
function c_bucket(t,x,y)
 local key=t..":"..x..","..y
 if not c_buckets[key] then
  c_buckets[key]={}
 end
 return c_buckets[key]
end

-- updates bucket positions
-- for dynamic entities
function c_update_buckets()
 for e in all(entities_with.dynamic) do
  c_update_bucket(e)
 end
end

-- actual bucket update for
-- entity "e". takes care to
-- only update when needed,
-- as switching buckets is
-- costly.
function c_update_bucket(e)
 if (not e.pos or not e.tags) return 
 local bx,by=c_bkt_coords(e)
 if not e.bkt or e.bkt.x~=bx or e.bkt.y~=by then
  if e.bkt then
   for t in all(e.tags) do
    local old=c_bucket(t,e.bkt.x,e.bkt.y)
    del(old,e)
   end
  end
  e.bkt=v(bx,by)  
  for t in all(e.tags) do
   add(c_bucket(t,bx,by),e) 
  end
 end
end

-- iterator that goes over
-- all entities with tag "tag"
-- that can potentially collide
-- with "e" - uses the bucket
-- structure described earlier.
function c_potentials(e,tag)
 local cx,cy=c_bkt_coords(e)
 local bx,by=cx-2,cy-1
 local bkt,nbkt,bi={},0,1
 return function()
  -- ran out of current bucket,
  -- find next non-empty one
  while bi>nbkt do
   bx+=1
   if (bx>cx+1) bx,by=cx-1,by+1
   if (by>cy+1) return nil
   bkt=c_bucket(tag,bx,by)
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

-- resets the collision system,
-- making all collision buckets
-- empty again
function collision_reset()
 c_buckets={}
end

-- collision detection main
-- function - detects all
-- requested collisions
function do_collisions()
 -- make sure our bucket
 -- structure is up to date
 c_update_buckets()
 -- iterate over all entities
 -- looking for collisions
 for e in all(entities_with.collides_with) do
  -- ...and all tags they're
  -- interested in
  for tag in all(e.collides_with) do
   -- choose the more efficient
   -- path depending on how
   -- many potential collisions
   -- there are
   local nothers=
    #entities_tagged[tag]  
   if nothers>4 then
    -- for a large number of
    -- possible colliders,
    -- we iterate over our
    -- bucket structure, since
    -- it's more efficient
    for o in c_potentials(e,tag) do
     if o~=e then
      -- get the colliders for
      -- each object
      local ec,oc=
       c_collider(e),c_collider(o)
      -- if both have one,
      -- check for collision
      -- between them
      if ec and oc then
       c_one_collision(ec,oc)
      end
     end
    end
   else
    -- for small numbers, we
    -- just iterate the
    -- entities directly
    for oi=1,nothers do
     local o=entities_tagged[tag][oi]
     -- quick check to rule out
     -- collisions quickly
     local dx,dy=
      abs(e.pos.x-o.pos.x),
      abs(e.pos.y-o.pos.y)
     if dx<=20 and dy<=20 then
      -- quick check passed,
      -- do proper collisions
      -- using hitboxes
      local ec,oc=
       c_collider(e),c_collider(o)
      if ec and oc then
       c_one_collision(ec,oc)
      end
     end
    end
   end     
  end 
 end
end

-- manually check for collision
-- between "box" and object with
-- one of the given "tags"
function c_check(box,tags)
 local fake_e={pos=v(box.xl,box.yt)} 
 for tag in all(tags) do
  for o in c_potentials(fake_e,tag) do
   local oc=c_collider(o)
   if oc and box:overlaps(oc.b) then
    return oc.e
   end
  end
 end
 return nil
end

-- checks for one collision
-- and calls the reaction
-- callbacks on each object
function c_one_collision(ec,oc)
 if ec.b:overlaps(oc.b) then
  c_reaction(ec,oc)
  c_reaction(oc,ec)
 end
end

-- calls the :collide() method
-- on a colliding object, if
-- one exists. if the return
-- value is c_push_out or
-- c_move_out, it acts on
-- that - separating the
-- colliding entities by moving
-- one of them.
function c_reaction(ec,oc)
 local reaction,param=
  event(ec.e,"collide",oc.e)
 if type(reaction)=="function" then
  reaction(ec,oc,param)
 end
end

-- returns the collider for
-- a given entity.
function c_collider(ent)
 -- colliders are cached
 -- for efficiency, but they
 -- are only valid for one
 -- frame
 if ent.collider then 
  if ent.coll_ts==g_time or not ent.dynamic then
   return ent.collider
  end
 end
 -- nothing cached, create
 -- new collider
 local hb=state_dependent(ent,"hitbox")
 if (not hb) return nil
 local coll={
  b=hb:translate(ent.pos),
  e=ent
 }
 -- cache it and return
 ent.collider,ent.coll_ts=
  coll,g_time
 return coll
end

-- reaction function, used by
-- returning it from :collide().
-- cause the other object to
-- be pushed out so it no
-- longer collides.
function c_push_out(oc,ec,allowed_dirs)
 local sepv=ec.b:sepv(oc.b,allowed_dirs)
 ec.e.pos+=sepv
 if ec.e.vel then
  local vdot=ec.e.vel:dot(sepv)
  if vdot<0 then
   if (sepv.y~=0) ec.e.vel.y=0
   if (sepv.x~=0) ec.e.vel.x=0
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

-------------------------------
-- system:
--  support
--  basically objects being
--  supported by floors
-------------------------------

function do_supports()
 -- entities that want support
 -- have a special collision box
 -- called the "feetbox"
 for e in all(entities_with.feetbox) do  
  local fb=e.feetbox
  if fb then
   -- look for support
   fb=fb:translate(e.pos)
   local support=c_check(fb,{"walls"})
   -- if found, store it for
   -- later - entity update
   -- functions can use the
   -- information
   e.supported_by=support
   -- objects supported by
   -- something move with
   -- whatever supports them
   -- (e.g. standing on 
   -- moving platforms)
   if support and support.vel then
    e.pos+=support.vel
   end
  end
 end
end

-------------------------------
-- entity:
--  parallax background
-------------------------------

bg=entity:extend({
 -- draws early so
 -- that everything covers it
 draw_order=0
})
 function bg:render()
  -- applies the camera
  -- with a small multiplier
  -- so the background moves
  -- less than the foreground
  g_cam:apply(0.2)
  map(109,0,-2,0,19,20)
  map(109,0,150,0,19,20)
 end

-------------------------------
-- entity:
--  level map
-------------------------------

-- the level entity only draws
-- the level using map().
-- collisions are taken care of
-- by individual solid/support
-- entities created on level
-- initialization.
level=entity:extend({
 draw_order=1
})
 function level:init()
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
      pos=v(x,y)*8,
      tile=blk
     })
     -- register the entity
     e_add(e)
     -- replace the tile
     -- with empty space
     -- in the map
     mset(b.x+x,b.y+y,0)
     blk=0
    end
    -- check what type of tile
    -- this is
    local btype=block_type(blk)
    if btype then
     -- it's not empty,
     -- so it gets an entity
     local b=btype({
      pos=v(x,y)*8,
      map_pos=v(x,y),
      typ=bt
     })
     -- register only if needed
     -- (walls completely
     -- surrouned by other
     -- walls aren't)
     if (b.needed) e_add(b)
    end
   end
  end
 end
 -- renders the level
 function level:render()
  palt(3,false)
  map(self.base.x,self.base.y,
   0,0,self.size.x,self.size.y)
 end

-- solid blocks push everything
-- out
solid=static:extend({
 tags={"walls"},
 hitbox=box(0,0,8,8)
})
-- supports are blocks you can
-- stand on, but they don't
-- push you out if you jump
-- from below them
support=solid:extend({
 tags={"walls","bridge"},
 hitbox=box(0,0,8,1)
})
 function solid:init()
  -- magic for collision detection
  -- basically, each block
  -- will only push the player
  -- out in the direction of
  -- empty space
  local dirs={v(-1,0),v(1,0),v(0,-1),v(0,1)}
  local allowed={}
  local needed=false
  for i=1,4 do
   local np=self.map_pos+dirs[i]
   allowed[i]=
    block_type(mget(np.x,np.y))
     ~=solid
   needed=needed or allowed[i]
  end
  self.allowed=allowed
  self.needed=needed
 end
 
 -- solids push the player
 -- out
 function solid:collide(e)
  return c_push_out,self.allowed
 end
 
 -- supports only push the
 -- player out conditionally
 function support:collide(e)
  if (not e.vel) return
  local dy,vy=e.pos.y-self.pos.y,e.vel.y
  if vy>0 and dy<=vy+1 then
   return c_push_out,{false,false,true,false}   
  end
 end

-- block types depend on the
-- sprite flags set in the
-- sprite editor. flag 0 set
-- means a solid block, flag 1 -
-- a support, bridge-type block
function block_type(blk)
 if (fget(blk,0)) return solid
 if (fget(blk,1)) return support
 return nil
end

-------------------------------
-- entity:
--  spikes
-------------------------------

spikes=entity:extend({
 -- different hitboxes for
 -- each tile - different spike
 -- orientations
 hitboxes={
  [80]=box(1,1,7,7),
  [178]=box(1,4,7,8),
  [179]=box(1,0,7,4),
  [163]=box(0,1,4,7),
  [147]=box(4,1,8,7)
 },
 -- spikes kill the player,
 -- so they want collisions
 collides_with={"guy"}
})
spikes:spawns_from(
 178,179,163,147,80
)
 -- choose the right hitbox
 -- on initialization
 function spikes:init()
  self.hitbox=spikes.hitboxes[self.tile]
  self.sprite={idle={self.tile}}
 end
 -- kill on collision
 function spikes:collide(o)
  o:kill()
 end
 -- rendering (just the default
 -- one)
 function spikes:render()
  spr_render(self)
 end

-------------------------------
-- entity: launcher
-------------------------------

-- launchers are trampolines
-- you can jump on
launcher=entity:extend({
 -- launch on collision,
 -- so need to know about them
 collides_with={"guy"},
 hitbox=box(0,5,8,8),
 -- have two states with
 -- different sprites
 sprite={
  idle={136},extended={137}
 }
})
launcher:spawns_from(136)
	-- on collision, we check
	-- if we were actually jumped
	-- on or just walked into
 function launcher:collide(o)
  if self.state=="idle" and
   not o.supported_by then
    -- detected player jumping
    -- on this, change state
    -- and launch player up
    self:become("extended")
    o:become("fly")
    o.vel=v(o.vel.x,-4.4)   
  end
 end
 function launcher:extended(t)
  -- when extended, we just
  -- return to normal after
  -- 15 frames
  if (t>=15) self:become("idle")
 end
 
-------------------------------
-- entity: ladder
-------------------------------
 
-- the ladder entity actually
-- takes care of all ladder-like
-- objects - ropes, vines, etc.
ladder=entity:extend({
 tags={"ladder"},
 hitbox=box(2,-1,6,8)
})
-- that's why it spawns from
-- all those tiles
ladder:spawns_from(
 65,97,113,114,115,
 81,66,82,98
)
 -- the entity only handles
 -- rendering - climbing
 -- happens in player code
 function ladder:render(p)
  palt(3,false)
  spr(self.tile,p.x,p.y)
 end

-------------------------------
-- entity: coin
-------------------------------
   
coin=entity:extend({
 -- coins have an animated
 -- sprite with 4 frames
 sprite={
  idle={184,185,186,187,delay=4}
 },
 -- they disappear on collision
 collides_with={"guy"},
 hitbox=box(0,0,8,8)
})
coin:spawns_from(184)
 -- randomize self.t to
 -- make coins start their
 -- animations from different
 -- spots
 function coin:init()
  self.t+=rnd()*6
 end
 -- on collision, disappear
 -- point-counting would happen
 -- here, if we had it
 function coin:collide(o)
  self.done=true
 end

-------------------------------
-- entity: moving platform
-------------------------------

-- moving platforms come
-- in two sizes
platform=entity:extend({
 -- they start out moving
 state="moving",
 -- they are tagged as walls,
 -- since they behave exactly
 -- the same - other than moving
 tags={"walls"},
 sprite={idle={162}},
 -- they collide with other walls
 -- and turn around when they do
 collides_with={"walls"},
 hitbox=box(0,0,8,8)
})
-- wide platforms just override
-- the looks and the hitbox
wide_platform=platform:extend({
 sprite={
  idle={176},
  width=2
 },
 hitbox=box(0,0,16,8)
})
platform:spawns_from(162)
wide_platform:spawns_from(176)
 -- platforms start out
 -- moving to the right
 function platform:init()
  self.vel=v(1,0)
 end
 -- platforms have two
 -- states: moving and waiting
 -- after they hit something
 function platform:moving()
 end
 function platform:waiting(t)
  if t>=40 then
   -- 40 frames after colliding
   -- we start moving again
   -- in the opposite direction
   self.vel=self.next_vel
   self:become("moving")
  end
 end
 function platform:collide(o)
  if o:is_a("walls") then
   -- collision with other
   -- wall/platform - wait,
   -- then turn around
   if (#self.vel>0) then
    self.next_vel=-self.vel
   end
   self.vel=v(0,0)
   self:become("waiting")
   -- also, move out to avoid
   -- penetrating the other
   -- object
   return c_move_out
  end
  -- when colliding with player,
  -- we act like a normal wall
  if (o:is_a("guy")) return c_push_out
 end

-------------------------------
-- entity: water
-------------------------------

water=entity:extend({
 -- water kills, so collisions
 -- are needed
 hitbox=box(0,0,8,8),
 collides_with={"guy"},
 -- colors for surface animation
 colors={5,12,12,6,6,7}
})
water:spawns_from(96)
 function water:init()
  -- initialize sine wave
  -- offsets for surface
  -- animation
  self.offsets={}
  for x=0,7 do
   self.offsets[x]=rnd()
  end
 end
 -- kill player on contact
 function water:collide(o)
  if o:is_a("guy") then
   o:kill()
  end
 end
 -- rendering
 function water:render(p)
  -- first, the tile
  spr(96,p.x,p.y)
  -- then, the 8 pixels
  -- on the surface will
  -- flash according to
  -- sine waves for a "wavy"
  -- appearance
  for x=0,7 do
   local sv=sin(self.t/40+self.offsets[x])*3+4
   local c=self.colors[flr(sv)]
   pset(p.x+x,p.y,c)
  end
 end

-------------------------------
-- entity: bat
-------------------------------
 
bat=entity:extend({
 -- it's an enemy
 tags={"enemy"},
 -- starts out in the 'fly' state
 state="fly",
 -- moves, starts with 0 velocity
 vel=v(0,0),
 -- same animation for
 -- both states
 sprite={
  fly={32,33,34,33,delay=4},
  back={32,33,34,33,delay=4}
 },
 -- draw order 5 to render
 -- in front of walls
 draw_order=5,
 -- collides with walls (so
 -- it doesn't go through them)
 -- and the player (to kill)
 collides_with={"guy","walls"},
 hitbox=box(2,2,6,6),
})
bat:spawns_from(32)
 function bat:init()
  -- bats remember their origin
  -- so they can return there
  -- in the "back" state
  self.origin=self.pos
 end
 function bat:fly(t)
  -- bats fly by randomly
  -- changing their velocity
  self.vel=v(rnd()-0.5,rnd()-0.5)
  self.vel*=1.75
  -- after a while spent flying,
  -- they go back to their
  -- origin
  if (t>120) self:become("back")
 end
 function bat:back(t)
  -- going back to origin
  -- is done by calculating
  -- a vector to there and
  -- normalizing it to limit
  -- speed
  self.vel=(self.origin-self.pos)  
  if #self.vel>0.25 then   
   -- we're not there yet
   self.vel=self.vel:norm()*0.5
  else
   -- we're there, start
   -- flying away again
   self:become("fly")
  end
 end  
 -- different behaviour
 -- depending on what we
 -- collide with
 function bat:collide(o)
  if o:is_a("guy") then
   o:kill()
  else
   return c_move_out
  end
 end

-------------------------------
-- entity: bird
-------------------------------

-- birds go back and forth
-- without regard to gravity
bird=entity:extend({
 state="fly",
 -- animation, flips set to true
 -- since the bird is either
 -- going right or left
 sprite={
  fly={35,36,37,37,36,35,delay=6},
  flips=true
 },
 draw_order=5,
 -- start out going to
 -- the right
 vel=v(0.5,0),
 -- collisions
 collides_with={"guy","walls"},
 hitbox=box(2,2,6,6)
})
bird:spawns_from(52)
 -- turn around on collision,
 -- kill player on contact
 function bird:collide(o)
  if o:is_a("walls") then
   self.vel=-self.vel
  end
  if o:is_a("guy") then
   o:kill()
  end
 end

-------------------------------
-- entity: enemy spearman
-------------------------------

spearman=entity:extend({
 -- starts out going right
 state="walking",
 vel=v(0.5,0),
 -- affected by gravity
 weight=0.2,
 -- has a few animated states
 sprite={
  aggro={195},
  walking={195,196,195,197,delay=6},
  charge={195,196,195,197,delay=3},
  fly={193},
  offset=v(-4,-13),
  height=2,
  flips=true
 },
 -- holds a spear, its position
 -- depends on animation frame
 -- while walking - these
 -- are the offsets
 spear_pos={
  v(-2,-7),v(-1,-7),
  v(-2,-7),v(-2,-8)
 },
 -- draws in front of most
 -- things
 draw_order=10,
 -- has both hitbox and feetbox
 -- since it stands on floors
 collides_with={"walls","guy"},
 hitbox=box(-2,-10,2,-1),
 feetbox=box(-4,-1,4,-0.999),
 -- has an additional box it
 -- uses to check terrain in
 -- front of itself - to turn
 -- around before it falls
 floorbox=box(-2,0,2,1)
})
spearman:spawns_from(19)
 -- default "patrol" state
 function spearman:walking()
  -- feel for ground, turn
  -- around if it'd fall
  local feel=self:feel_around()
  if (feel) self:turn()
  -- look for player and
  -- become aggressive if
  -- you see him/her
  if self:check_aggro() then
   self:become("aggro")
  end
 end
 
 -- when aggro, the spearman
 -- just stands in place
 -- readying a charge
 function spearman:aggro(t)
  self.vel=v(0,0)
  -- charge after 20 frames
  if (t>=20) self:become("charge")
 end
 
 -- charging is like walking,
 -- but faster
 function spearman:charge()
  self.vel=v(self.flipped and -1 or 1,0)
  -- we only turn around if we
  -- see a wall, but not if we're
  -- going to fall - letting the
  -- player goad spearmen into
  -- falling from their platform
  local feel=self:feel_around()
  if feel=="wall" then
   self:turn()
  end
  -- since we can actually
  -- fall, we should handle
  -- that
  self:do_falls()
 end
 
 -- fly state - when falling
 -- from a platform after
 -- a charge
 function spearman:fly()
  -- did we land?
  if self.supported_by then
   self:become("walking")
  end
  -- did we fall off-screen?
  self.done=self.pos.y>g_level.size.y*8
 end
 
 -- turning
 function spearman:turn()
  self:become("walking")
  self.vel=self.flipped
   and v(0.5,0) or v(-0.5,0)
 end
 
 -- feeling around, returns
 -- "wall" if a wall is in front,
 -- "fall" if we ran out of
 -- platform to walk on,
 -- or nil if none of that
 -- happened
 function spearman:feel_around()
  local felt=nil
  if self.prev and #(self.prev-self.pos)==0 then
   felt="wall"
  elseif not self:check_ground() then
   felt="fall"
  end
  self.prev=self.pos
  return felt
 end
 
 -- check for player - we become
 -- aggressive when the player
 -- is on roughly the same
 -- level as us and close by
 function spearman:check_aggro()
  local dy=g_guy.pos.y-self.pos.y
  if (abs(dy)>2) return false
  local dx=g_guy.pos.x-self.pos.x
  return abs(dx)<64 and (sgn(dx)==sgn(self.vel.x))
 end
 
 -- check if there is ground
 -- in front of us - uses
 -- the floorbox to query
 -- the collision system
 function spearman:check_ground()
  if not self.supported_by then
   return true
  end
  local projected_move=
   self.pos+v(self.vel.x*8,0)
  local box=self.floorbox:translate(projected_move)  
  return c_check(box,{"walls"})~=nil
 end
 
 -- fall if not supported
 -- by a floor
 function spearman:do_falls()
  if not self.supported_by then
   self:become("fly")
  end
 end
 
 -- kill player on collision
 function spearman:collide(o)
  if o:is_a("guy") then
   o:kill()  
  end
 end
 
 -- custom rendering - draws
 -- the standard animated
 -- sprite first, then draws
 -- a spear on top (depending
 -- on the animation)
 function spearman:render(p)
  -- draw person
  local frame=spr_render(self)
  -- draw the spear
  local sp=self.spear_pos[frame]
  if self.flipped then
   sp=v(-sp.x-7,sp.y)
  end
  sp+=self.pos
  spr(63,sp.x,sp.y,1,1,self.flipped)
  -- if we're aggroed, draw
  -- an exclamation point to
  -- alert the player
  if self.state=="aggro" then
   print("!",self.pos.x-1,self.pos.y-18,8)
  end
 end  

-------------------------------
-- encja:
--  chlopek
-------------------------------

-- the main player entity
guy=entity:extend({
 tags={"guy"},
 -- starts falling down
 state="fly",
 -- moves
 vel=v(0,0),
 -- affected by gravity,
 -- except when climbing
 weight={0.2,climb=0},
 -- various animations
 sprite={
  walk={205,206,205,207,delay=5},
  idle={205},
  crouch={202,offset=v(-4,-10)}, 
  fly={204},
  dead={207},
  climb={200,201,delay=6,flips=false},
  offset=v(-4,-13),
  height=2,
  flips=true
 },
 draw_order=10,
 -- collides with stuff
 collides_with={"walls","ladder"},
 -- hitbox is smaller when
 -- crouching
 hitbox={
  box(-2,-10,2,-1),
  crouch=box(-2,-6,2,-1)
 },
 -- has a feetbox to be able
 -- to stand on floors
 feetbox=box(-2,-1,2,-0.999)
})
guy:spawns_from(205)
 -- stores itself in a global
 -- when created - accessing
 -- the player entity easily
 -- from other code
 -- is very convenient
 function guy:init()
  g_guy=self
 end
 -- flying
 function guy:fly(t)
  -- altitude control for jumping
  -- the longer you hold the
  -- jump button, the higher
  -- the jump
  if btn(4) and not btn(3) and t<10 and not self.dropping then
   self.vel.y=-1.75
  end
  -- air control - you can
  -- move left/right when
  -- airborne, but more sluggishly
  -- than on the ground
  if (btn(0)) self.vel-=v(0.3,0)
  if (btn(1)) self.vel+=v(0.3,0)
  -- air resistance - limits
  -- both downward speed and
  -- the horizontal speed
  -- and jump length
  self.vel.x*=(1/1.3)
  -- different animation
  -- frames for jumping up/
  -- falling
  self.sprite.fly[1]=
   self.vel.y>0 and 203 or 204
  -- did we land?
  if self.supported_by and self.vel.y>0 then
   self.vel=v(0,0)
   self:become("idle")
  end
  -- did we hit a ladder?
  if self.on_ladder and self.vel.y>=0 then
   self:become("climb")
  end
  -- did we fall off-screen?
  if self.pos.y>g_level.size.y*8 then
   self:kill()
  end
 end
 -- from the idle state, we
 -- can start walking or jump
 function guy:idle()
  self:do_walking()
  self:do_verticals()
  self:do_ladders()
 end   
 -- from the walking state, we
 -- can continue walking, stop,
 -- or jump
 function guy:walk(t)
  self:do_walking()
  self:do_verticals()
  self:do_ladders()
 end
 -- when crouching, we can't walk
 function guy:crouch()
  if (not btn(3)) self:become("idle")
  -- slide if our velocity
  -- was non-zero when we crouched
  self.vel.x*=0.8
  -- if we're on a bridge-type
  -- tile, down+jump will drop
  -- us one level down
  if btnp(4) and self.supported_by:is_a("bridge") then
   self.pos+=v(0,2)
   self:become("fly")
   return
  end
  self:do_verticals()
 end
 -- "dead" state - dead players
 -- aren't removed to keep
 -- other code working properly
 function guy:dead()
  -- restart the level on
  -- button press
  if btnp(4) or btnp(5) then
   schedule(restart_level)
  end
  -- stop falling at some point
  -- to prevent the y-position
  -- from overflowing
  if self.pos.y>g_level.size.y*8+50 then
   self.vel=v(0,0)
   self.weight=0
  end
 end
 -- when climbing, you can move
 -- in all directions unaffected
 -- by gravity
 function guy:climb()
  -- you can jump from
  -- ladders
  if btnp(4) then
   self.vel.y=-1.75
   self.on_ladder=false
   self:become("fly")
   return
  end
  -- when you move away from
  -- the ladder, you start
  -- falling
  if not self.on_ladder then
   self:become("fly")
   return
  end
  -- 4-direction movement
  self.vel=v(0,0)
  if (btn(0)) self.vel-=v(0.6,0)
  if (btn(1)) self.vel+=v(0.6,0)
  if (btn(2)) self.vel-=v(0,0.6)
  if (btn(3)) self.vel+=v(0,0.6)
  -- only animate while
  -- moving (dirty trick,
  -- sorry)
  if #self.vel==0 then
   self.t-=1
  end
  -- reset the 'on_ladder'
  -- flag - it will be set
  -- back to true during
  -- collision detection if
  -- we're still on one
  self.on_ladder=false
 end
 
 -- collisions
 function guy:collide(o)
  -- colliding with ladders
  -- just sets a flag
  if o:is_a("ladder") then
   self.on_ladder=true
  end
 end
   
 -- getting killed turns
 -- off collisions and
 -- makes us dead
 function guy:kill()
  self.vel=v(0,-1)
  self.hitbox=false
  self.feetbox=false
  self:become("dead")
 end
 -- common multiple-state stuff
 function guy:do_walking()
  -- determine walking speed
  -- based on input
  self.vel=v(0,0)
  if (btn(1)) self.vel=v(1,0)
  if (btn(0)) self.vel=v(-1,0)
  -- change state based
  -- on whether we're moving
  if self.vel.x~=0 then
   self:become("walk")
  else
   self:become("idle")
  end
 end
 
 function guy:do_verticals()
  -- did we fall down?
  if not self.supported_by then
   self:become("fly")
   return
  end
  -- are we jumping?
  if (btn(4)) then
   self:become("fly")
   self.vel.y=-1.75
  end
  -- are we crouching?
  if (btn(3)) then
   self:become("crouch")
  end  
 end
 
 function guy:do_ladders()
  -- should we start climbing?
  if self.on_ladder and (btn(2) or btn(3)) then
   self:become("climb")
  end
 end
 
 -- hud rendering
 function guy:render_hud()
  function p(s,x,y,c)
   print(s,x-#s*2,y+1,0)
   print(s,x-#s*2+1,y,0)
   print(s,x-#s*2,y,c)
  end
  if self.state=="dead" then
   p("press Ž to restart",
    64,100,10)
   p("- you died -",
    64,94,14)
  end
 end

-------------------------------
-- camera
-------------------------------

cam=object:extend({
 -- hold the player
 -- in a window of this size
 window_size=v(20,20),
 p=v(0,0)
})
 function cam:init()
  local ws=self.window_size
  self.window=vbox(
   -ws*0.5-v(64,64),
    ws*0.5-v(64,64)
  )
  self.limits=vbox(
   v(0,0),
   self.level.size*8-v(128,128)
  )
 end
 function cam:update()
  local gp,w,l=self.guy.pos,
   self.window,self.limits
  -- player tracking
  self.p.x=mid(self.p.x,
   gp.x+w.xl,gp.x+w.xr)
  self.p.y=mid(self.p.y,
   gp.y+w.yt,gp.y+w.yb)
  -- limit to map size
  self.p.x=mid(self.p.x,l.xl,l.xr)
  self.p.y=mid(self.p.y,l.yt,l.yb)
 end
 -- apply the camera
 -- transformation
 function cam:apply(magnitude)
  if (not magnitude) magnitude=1
  self:update()
  local d=self.p*magnitude
  camera(d.x,d.y)
 end

-------------------------------
-- initialization
-------------------------------

function _init()
 level_settings={
  base=v(0,0),
  size=v(47,27)
 }
 restart_level()
end

function restart_level()
 -- reload map
 reload(0x2000,0x2000,0x1000)
 -- reset systems
 entity_reset()
 collision_reset()
 -- create entities
 e_add(bg())
 g_level=e_add(level(
  level_settings
 ))
 -- and the camera
 g_cam=cam({
  guy=g_guy,
  level=g_level
 })
end

-------------------------------
-- main loop, just
-- calls the other systems
-------------------------------

g_time=0
function _update60()
 if scheduled then
  scheduled()
  scheduled=nil
 end
 e_update_all()
 do_movement()
 do_collisions()
 do_supports()
 g_time+=1
end

function _draw()
 cls()
 r_render_all("render")
 camera()
 r_render_all("render_hud")
end

__gfx__
0000000030000003333333333304030333333333333333333333333333333333f04442000044420e304221e0f042210e3042220e30422210304222100f422110
000000000d76d5003300033330420040330000333333333333000033330000330022210ef0222100302f0100000000000f4400000f2942e030f942030229421e
00700700576d55503077600300422420309944033300003330aaa403301101033000000000000003333333330420011000000110000000000000000030000000
0007700056ddd550077776702442442200444200304424030aa44940011110003000420330420003333333330000000004200000304201030420011033042033
00077000d5555555306776032444242240422202044244200a4aa240011000003330000330000333333333333333333300003333300000030000000033300333
007007000055550006776670044242204002200202444220094a9240010010003333333333333333333333333333333333333333333333333333333333333333
000000000211112005666500024422200200002001222210042a2940010100003333333333333333333333333333333333333333333333333333333333333333
00000000002222003055510300222200001111000011110000494400000000003333333333333333333333333333333333333333333333333333333333333333
3333333330000003333333333300033333333333333333333333333333333333f08222000082220430822240f08222043082220030822210308222100f822210
000330000d76d50030000333304200333300003333333333003000333300000300288204f0288200302f0200000000000f8800000f28824030f8820302288224
02100120576d5550077760330044420330499203330000339a0aa903301101003000000000000003333333330420022000000220000000000000000030000000
02944b2056ddd5507777760344444200004442003044220300aa449001111000300042033042000333333333000000000f40000030f402030f400120330f4033
00022000d50000000767060024422440424222220442ff200a94ff200110ff203330000330000333333333333333333300003333300000030000000033300333
04494b20112f4ff060777992042f422000000000042f4ff0094f4ff0010f4ff03333333333333333333333333333333333333333333333333333333333333333
04944b20042fffe006666444042fffe002ffffe0042fffe0094fffe0010fffe03333333333333333333333333333333333333333333333333333333333333333
00222200002eee0000555000002eee00002eee00002eee00004eee00000eee003333333333333333333333333333333333333333333333333333333333333333
3333333333333333333333330333003333333333330033333333333330003333f0fff900f0fff90030241110f099ff04309fff003099ff1030499f100f499f00
0333333030133103331331338000e8000033003300e200333333003300e0033300f9990400f99904304f0200002211000f4911000f49ff4030f49f0330499f14
5013310505d00d5030d00d03288282a98000e8008082e8000300e800808203333022110030221100333333330420022002220220002211000022110030221100
15d00d51555dd555055dd550028800002ee822a92e8822a9808822a9228800333011f40330f4220333333333000000000f40000030f402030f400120330f4033
005dd500100dd001550dd055308820330222000002820000088800000222e8033000000330000003333333333333333300003333300000030000000033300333
330dd033033003301030030130820333302820333000003330288803300022a03333333333333333333333333333333333333333333333333333333333333333
33300333333333330333333033020333330003333333333330222033333300093333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333303333333333333333333309000903333333303333333333333333333333333333333333333333333333333333333333333333
f030030f0f0000f03333333330003333333333333330033333333333333003333333333333777333336663333333333333333300333333333333333333333333
0f0e10f00f0e10f0333333330a9a03333000000333078033300000033307a0333333333333377733333ddd333303333333333070333333333300333333333003
00ee210000ee210030003333042203330a110090307e880330a76c03307e803333333333333366333333553300200003333307603300000330a9000000000510
0f2221f0f022210f0a9a03330a99403330999903077e88803077cc0330aa99033333773333336633333355334427777033307603306566500a009aaa44422677
0020010000200100042200333004203309aa99400ee82220306c550330794403333366333333dd33333333332226666730076033305500030900409400000510
0f0220f00f0220f00a994a030a4a490309a9944030882103306d5103309920333333dd3333335533333333330020000030220333042033333094000033333003
f002100f0f0210f0300444a0000004a004994420330810333000000330490033333d533333355333333333333303333330020333000333333300333333333333
03300330303003030a4a4990333090a030000003333003333333333330aa94033355333333333333333333333333333302003333333333333333333333333333
00000000001001000070250001111100030130103313331300313100000000000001000000000001100000000000100000000000000000001000000000000000
000000000444422000065000411111103bbb3bb3bb3bbb3bbb3b3bbb3bb3bbb00010110000000010100000000000100000000000000000100000000000000000
0000000002222220000110000222220003bb3b333b3b3b3bb33313b33bb3bb330010000000000010010000000000100100100000000000000100000000001000
00000000001001000002100040000010303313313331331331311133331133130010000000000101001100000000011000000000000001000000000000000000
00000000001001000004200044222110022100000000000000000000000000200101100000000100001000000000010001000000000000000010000000000100
00000000042444200002400014442100094101220121102102212021211022200100000000001010001000000000001001000000000010000010000000000010
00000000022222100004200041111010044210200111101101111011111012001011000000001000000110000000001010000000000010000000000000000010
00000000001001000004100022222110011212100101000001010000010012001000000000001000000100000000000100000000000000000001000000000001
70070000005010000004200044244110022102100000000000000000000000200000100000000001000000000000000000000000000000000000000000000000
6006007000d0d0000002400000200110094412100000000011010110011012200101100000000000010000001000000000001000011111111111111111111000
650550600050d0000004200011211110094210000000000011000111111012201000010000000010001010000101100000100000000000000000000000000000
55020050000500000004100004422210042102200000000000000010111011200101000000000101000000000000010000000010001000000001000000010000
02040020006050000004200040042210022102100000000000000000010000100100000000011000010010110010000000010100001001000001000010010000
0412114100d0d0000002400020022110094410000000000000000000000220201000100000000100000000010001010000000100001000000101000110010000
121111210050d0000004200002212110094410110000000000000000011010200000000000110000000001000000000100000000101000100101000111010010
01101110000500000004100001122110044102110000000000000000011000201100000001000000000000000000000100001010101000100101001011010010
c7c76c76000b30100004200004221210022102200000000000000000001100200000000000000000001111101101100000000000000000000000000000000110
dddddddd3b0b30030002400002114110094412100000000000100010001102200000000000000000011110011101011100111111111111101111111100101111
55555555030335000004200002442110094210000011000000000000000001200000000000000000011100010110100001111111110110011111111101001100
11111111000b30110004100042222112042100000010000000001100010001200011000000010000011000000011010101111111100100010011110000000100
11111111100350100002400024444421022100000000000000000000000000200110010010011000011000010000011001110100100000010000001000110000
11111111005b303b0002200012222211041000000000110001100000000010000100100010001100010000010101000101100001000000010011000001100000
11111111100330300001100001111110021000000000000001000000000010201101101010101010011000010100010001000000000000010000000001000110
11111111010b30100000100004222110010000000000000000000000000000001001001010111010010000010000010000000000000000000000000000000000
11111111010b3001100b3501031b3130022100000000000000000000000112002442422200000000011000010101001000000000000000000000000000000000
11111111000351010100b3000b011b31002410100000000000000000000001001010111000000000011000010101001001110000000011110011000000011100
11111111010131000000335013bbb300000941000000000000100000001120001000110100000000010000010100101001111000000111010110000000111000
110111010001b0010b30b30100333003000941100000000001000010000120000000010000010000011000010010100001111100000111010100000001110000
101001100000b00030303510000110b0000210100100000001011100010020000000000010110100011000000010100001110100001110010000011001100000
00010001000030000100b303b00b30b3000022001001100010011001112100000000000010100101010000010000100001100000001110010000110000100000
00000000000010000000330003035030000000202021110200221021210000000000000010101001010000000000000001000010001100010000110000100000
0000000000000000010b3510110b3010000000020002222000000002000000000000000010111010000000000000000000000000000000000000010000000000
1100110000000000000000000000000007779779777977797779777977797790333333330000000030070303052222500000077d0777d00007700000077d0000
442044201000000100777600000222107fff47f47ff47ff47ff47ff27ff47ff43333333304444220070000700000000000775dd0507dd57d77dd77757dd0576d
222022201000000107777660042442107fff221122119ff29ff2121022117ff433333333022111103005500006666dd000d100000055005505507d50055077d5
222022201111111100705660244422217f9200000000000004400000000049f200000000330d503300575106064242d000070051000000001100000000006dd5
000100011000000107767650222224207f9019422222012121010222220202210444422030700503705556000642425000775051011055105105105555000551
0001000111111111007650000242422104201421111001111110011111041000022111100d033050000110030642425007765000000011100001105111150d65
1110111010000001006d000002222100000212100000000000000000010210400075d50030d75503060000600ddd5550076d5510000000000000001101150dd5
00000000100000010000100000000000022210000000000000000000000000200dd751100d700550303060030000000000550110000000000000000000000550
1000001110000011000021000000000707aa99410000000000000000011022400333333333333333333333333333333300700511000000000000000000555065
110001100100011000002100000007760a999421000000000111101001102140a0333333333333333333333333333333005005100000000000011000001150d5
010011000011010000002100000000550a9994210000000001000010000001404a03333333300333333333333333333300760000000000000001100000000050
00011000000110000010021000000007022110000000000000000000000000200a033333330650333000000033333303077d5051000000000000000000010065
0011000000001100011002100000777607aa14100000000000011110121222409a9033333305503307544820330000e0076d5051000000000100011000000dd5
011000000000011001000210000000550a99121000000000000100001111114020033333333003333000000030100803006d5000000000000000111000550555
110000000000001111010200000007770a9412100000000000000000000111402033333333333333333333333106d01300050510000000000000110001150010
10000000000000011001001000000055022110000000000000000000000000209a0333333333333333333333306ddd0300700110000000000000000001100d50
777ffff912222221244444427000000000aaa9000000000000000000010224003333333333333333333003333333333307600000000000000000000000000d60
7545544211111111222222226770000000a992020000000000000000010214003330033330000033330dd0333333333307650551000000000000000000150550
f4ff9ff1f9ff9ff97a77a7795500000000944202000000000000000000011400330cc03330dc7d0330c77c033333333300d00511000110000000000000150100
42211111442444227ee00ee4700000000002110101011010011010101000000030c77c0330c77c030d7777d03033333300500110000110000000011000000065
fff2fff9fff2fff97e0780f9677700000000000000000000000000000022100030c77c0330777cd00d7777d00e000033077500000500000000000150005510dd
5442f4525442f452ae0820f45500000000094044222102222221021220210000330cc033330c700330c77c0330800103076d5051551051000011000001155055
f9f1f4f9f9f1f4f97ef00ff4777000000000202111110111111101111010000033300333330d0333330dd0333106d01300d500005110110000150d5001150050
4211222142112221994944445500000000000000000000000000000000000000333333333330333333300333306ddd0300050100011000000000055000110d60
2444444444444442000000005756756707aa99410000000000000000122022403300003333000033333003333300003307700000000000000000000000000015
222222222222222200000000575705700a99942100000000000000001110214030477403304a9203330940333029a4030775051101100000100000101100dd00
7a77a7797a77a77900000000070700700a999421000000000000000111102140047aaa4030aaa40333094033304aaa03006d50510100011000110110150d5500
7ee9ee900eee9ee400000000000700000221211001111111011110111100112007a79a9030a9a40333094033304a9a0300d550000001011001100000500d5001
79f7970780ff79f900007000000000000000000000000000000000000000000007a9aa9030a9a40333094033304a9a03000551dd0000000000000d5000d50100
ae779908207979f407007070000000000994999499949994994999949994999004aaa94030aaa40333044033304aaa0301100dd50dd00d51dd51d55000101100
7ef99ff00f9f99f407507575000000000921922122219221221922212221921030499403304a4203330440333024a403010005551551dd50d5500551dd500000
99494444994944447657657500000000021011101110111011011110111011003300003333000033333003333300003300000050011055000510000055000000
33333333333333333333333333333333333333333333333300000000000000003333333333333333333333333333333333333333333333333333333333333333
30000333300003333000033330000333300003333000033300000000000000003300003333000033003000330030003300300033003000330030003300300033
077760330777603307776033077760330777603307776033000000000000000030aaa40330aaa4039a0aa9039a0aa9039a0aa9039a0aa9039a0aa9039a0aa903
77777603777776037777760377777603777776037777760300000000000000000aa449400aa4494000aa449000aa449000aa449000aa449000aa449000aa4490
07670600076706000767060007670600076706000767060000000000000000000a4aa2400a4aa2400a94ff200a94ff200a94ff200a94ff200a94ff200a94ff20
6077799460777994607779946077799460777994607779940000000000000000094a9240094a9240094f4ff0094f4ff0094f4ff0094f4ff0094f4ff0094f4ff0
0666644406666444066664440666644406666444066664440000000000000000042a2940042a2940094fffe0094fffe0094fffe0094fffe0094fffe0094fffe0
00555000005550000055500000555000005550000055500000000000000000000049440000494400004eee00004eee00004eee00004eee00004eee00004eee00
30241110f099ff04309fff003099ff1030499f100f499f000000000000000000f08222000082220430822240f08222043082220030822210308222100f822210
304f0200002211000f4911000f49ff4030f49f0330499f14000000000000000000288204f0288200302f0200000000000f8800000f28824030f8820302288224
33333333042002200222022000221100002211003022110000000000000000003000000000000003333333330420022000000220000000000000000030000000
33333333000000000f40000030f402030f400120330f40330000000000000000300042033042000333333333000000000f40000030f402030f400120330f4033
33333333333333330000333330000003000000003330033300000000000000003330000330000333333333333333333300003333300000030000000033300333
33333333333333333333333333333333333333333333333300000000000000003333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333300000000000000003333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333300000000000000003333333333333333333333333333333333333333333333333333333333333333
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
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000001111111111111111111111111111100000000000000000000000000000000000000000000000000000094000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000094000
00000000000000000000000000000000000000000001000000010000000100000001000000000000000000000000000000000000000000000000000000094000
00000000000000000000000000000000000000000001000000010000000100001001000000000000000000000000000000000000000000000000000000094000
00000000000000000000000000000000000000000101000101010001010100011001000000000000000000000000000000000000000000000000000000044000
00000000000000000000000000000000000000000101000101010001010100011101001000000000000000000000000000000000000000000000000000044000
00000000000000000000000000000000000000000101001001010010010100101101001000000000000000000000000000000000000000000000000000000000
00000000000000000000000007779779777977901100110011001100110011001100110012222221000000000000000024444444444444420000000000000000
0000000000000000000000007fff47f47ff47ff44420442044204420442044204420442011111111000000000000000022222222222222220000000000000000
0000000000000000000000007fff221122117ff422202220222022202220222022202220f9ff9ff910000000000000007a77a7797a77a7790000000000000000
1100000000000000000000007f920000000049f2222022202220222022202220222022204424442200000000000000007ee9ee900eee9ee40000000000000000
1000000000000000000000007f9019422202022100010001000100010001000100010001fff2fff9000000000000000079f7970780ff79f90000000000000000
1000000000000000000000000420142111041000000100010001000100010001000100015442f4520000000000000000ae779908207979f40000000000000000
011000000000000000000000000212100102104011101110111011101110111011101110f9f1f4f900000000000000007ef99ff00f9f99f40000000000000000
01000000000000000000000002221000000000200000000000000000000000000000000042112221000000000000000099494444994944440000000000000000
00000000000000000000000007aa99410110224010000011000000000000000010000011777ffff9000000000000001000000000000000000000000000000000
0000000000000000000940000a999421011021401100011000000000000000000100011075455442000000000000000000000000000000000000000000000000
0010000010000000000940000a9994210000014001001100100000000000000000110100f4ff9ff1000000000000000100000000000000000000000000000000
00000000000000000009400002211000000000200001100000000000000000000001100042211111000000000000000000000000000000000000000000000000
00010001000000000009400007aa14101212224000110000000000000000000000001100fff2fff9000000000000000010000000000000000000000000000001
0000100100000000000440000a99121011111140011000000000000000000000000001105442f452000000000000000010000000000000000000000000000001
0000101000000000000440000a9412100001114011000000000000000000000000000011f9f1f4f9000000000000000000000000000000000000000000000010
00000100000000000000010002211000000000201000000000000000000000000000000142112221000000000000000001000000000000000000000000000010
00000100000000000000001007aa9941011022400000010000000010000000000000001000000000000000000000000000100000122222210000000000000100
0000100000000000004a92000a999421011021400000100000000000000000000000001000000000000000000000000000100000111111110000000000001000
000010000000000000aaa4010a999421000001400000100000000001000000000000000100000000000000001000000000100100f9ff9ff90000000000001000
000101000000000000a9a40002211000000000200001010000000000000000000000000011000000000000000000000000011000442444220000000000010100
000100000000000000a9a40007aa1410121222400001000000000000100000000000000010000000000000010000000000010000fff2fff90000000000010000
001010000000000000aaa4000a9912101111114000101000000000001000000000000000100000000000000100000000000010005442f4520000000000101000
0010000000000000004a42000a94121000011140001000000000009a0aa900000000000001100000000000100000000000001000f9f1f4f90000000000100000
00100000000000000000000002211000000000200010000000000000aa4490000000000001000000000000000000000000000100421122210000000000100000
01000000777ffff9777ffff9777ffff9777ffff9010000000000000a94ff20000000000000100000000000000000000000000000777ffff90000000001000000
101100007545544275455442754554427545544210110000000000094f4ff0000000100000100000000000000000000000000000754554420000000010110000
10000000f4ff9ff1f4ff9ff1f4ff9ff1f4ff9ff110000000000000094fffe0000000000000100100000000000000000000000000f4ff9ff10000000010000000
100000004221111142211111422111114221111110000000000100004eee00000001000000011000000000000000000000000000422111110000000010000000
01100000fff2fff9fff2fff9fff2fff9fff2fff90110000010011000822210000000000000010000000000000000000000000001fff2fff90000000101100000
000000005442f4525442f4525442f4525442f452000000001000110f2882400100100000000010000000000000000000000000015442f4520000000100000000
11000000f9f1f4f9f9f1f4f9f9f1f4f9f9f1f4f91100000010101000000000010010000000001000000000000000000000000010f9f1f4f90000001011000000
00000000421122214211222142112221421122210000000010111010f40200100000000000000100000000000000000000000010421122210000001000000000
0000000011011000000b3010031b3130100b35010000000003013010000000000000000000000010000000000000000012222221777ffff91222222100100100
00000000110101113b0b30030b011b310100b300000000003bbb3bb33bb3bbb00000000000000010000000000000000011111111754554421111111104444220
00000000011010000303350013bbb300000033500000000003bb3b333bb3bb3300000000000000010000000000000000f9ff9ff9f4ff9ff1f9ff9ff902222220
0000000000110101000b3011003330030b30b3010000000030331331331133131100000000000000110000000000000044244422422111114424442200100100
000000000000011010035010000110b03030351000000000022100000000002010000000000000001000000000000000fff2fff9fff2fff9fff2fff900100100
0000000001010001005b303bb00b30b30100b303000000000941012221102220100000000000000010000000000000005442f4525442f4525442f45204244420
000000000100010010033030030350300000330000000000044210201110120001100000000000000110000000000000f9f1f4f9f9f1f4f9f9f1f4f902222210
0000000000000100010b3010110b3010010b35100000000001121210010012000100000000000000010000000000000042112221421122214211222100100100
0000000000000000100b3501000b3010010b30010000000000000010000000200010000000000000000000000000000057567567777ffff95756756700100100
00000000000000010100b3003b0b3003000351010010000000000010011012200010000000000000000000000000000057570570754554425757057004444220
00000000000000100000335003033500010131001000000000000001111012200010010000000000101000000000000007070070f4ff9ff10707007002222220
11000000000000010b30b301000b30110001b0010000100000000000111011200000000000110000000000000000000000070000422111110007000000100100
100000000000000130303510100350100000b0000101000000000000010000100444422001100100001011000000000100000000fff2fff90000000000100100
10000000000000100100b303005b303b0000300000010000000000000002202002211110010010000000010000000001000000005442f4520000000004244420
01100000000000000000330010033030000010000000000000000000011010200075d50011011010000100000000001000000000f9f1f4f90000000002222210
0100000000000011010b3510010b3010000000000010100000000000011000200dd7511010010010000000000000001000000000421122210000000000100100
0000010000000000010b3001100b3501000000000000000000000000000000203313331300000000000000000000000000000000000001000010000000100100
0000000100000000000351010100b30000000000000000000000000001101220bb3bbb3b3bb3bbb0000000000000000000000000000010000010000004444220
00001000101000000101310000003350000000000000000000000000111012203b3b3b3b3bb3bb33000000001010000000000000000010000010010002222220
00010100000000000001b0010b30b301000000000000000000010000111011203331331333113313001100000000000000000000000101000001100000100100
01100001001011000000b00030303510000000000000000010110100010000100000000000000020011001000010110000000000000100000001000000100100
0001000000000100000030000100b303000000000000000010100101000220200121102121102220010010000000010000000000001010000000100004244420
11000000000100000000100000003300000000000000000010101001011010200111101111101200110110100001000000000000001000000000100002222210
000000000000000000000000010b3510000000000000000010111010011000200101000001001200100100100000000000000000001000000000010000100100
001000000000000000000000010b3001000000000000000003013010022102200001120002210000000000000000000000100000000000000000000000100100
0110000000000000000000000003510100000000000000003bbb3bb30944121000000100002410103bb3bbb00000000001100000001000010000000004444220
00010000000000000000000001013100000000000000000003bb3b330942100000112000000941003bb3bb330000000000010000100000001010000002222220
0100000000000000000000000001b001000000000000000030331331042100000001200000094110331133130001000001000000000010000000000000100100
0000000000000000000000000000b000000000000000000002210000022100000100200000021010000000201001100000000000010100010010110000100100
00100000000000000000000000003000000000000000000009410122041000001121000000002200211022201000110000100000000100000000010004244420
00000000000000000000000000001000000000000000000004421020021000002100000000000020111012001010101000000000000000000001000002222210
00000000000000000000000000000000000000000000000101121210010000000000000000000002010012001011101000000000001010000000000100100100
00000000000000000000000000000000000000000000000000000000022102100000000000000000022100000000000000000000000000000301301000313100
00000000000000000000000000000000000000000000000000000000094412103bb3bbb000000000002410103bb3bbb000000000000000003bbb3bb3bb3b3bbb
00000000000000000000000000000000000000000000000000000000094210003bb3bb3300000000000941003bb3bb33000000000000000003bb3b33b33313b3
00000000000000000000000000000000000000000000000000000000042102203311331300000000000941103311331300010000000100003033133131311133
00000000000000000000000000000000000000000000000000000000022102100000002000000000000210100000002010011000101101000221000000000000
00000000000000000000000000000000000000000000000000000000094410002110222000000000000022002110222010001100101001010941012202212021
00000000000000000000000000000000000000000006777000000000094410111110120000000000000000201110120010101010101010010442102001111011
00000000000000000000000000000000000000000067777700000000044102110100120000000000000000020100120010111010101110100112121001010000
00000000000001000000000000000000000000000060767000000000022102100001120000000000000000000221000003013010003131000000000000000000
0000000000000001011111111111111111111000499777060000000009441210000001000000000000000000002410103bbb3bb3bb3b3bbb3bb3bbb03bb3bbb0
00000000000010100000000000000000000000004446666000000000094210000011200010100000000000000009410003bb3b33b33313b33bb3bb333bb3bb33
00000000000101010010000000010000000100000005550000010000042102200001200000000000000000000009411030331331313111333311331333113313
00000000011000010010010000010000100100001500000010011000022102100100200000101100000000000002101002210000000000000000002000000020
00000000000100100010000001010001100100077622444010001100094410001121000000000100000000000000220009410122022120212110222021102220
00000000110000001010001001010001110100101500000010101010094410112100000000010000000000000000002004421020011110111110120011101200
000000010000001110100010010100101101001000204f0010111010044102110000000000000000000000000000000201121210010100000100120001001200
00000000000000000301301000313100003131000000000000313100000000000000000000000000000000000000000002210000000000000001120000011200
00000000000000003bbb3bb3bb3b3bbbbb3b3bbbbb3b3bbbbb3b3bbb3bb3bbb00000000000094000004a92000000000000241010000000000000010000000100
101000000000000003bb3b33b33313b3b33313b3b33313b3b33313b33bb3bb33000000000009400000aaa4000000000000094100001000000011200000112000
0000000000000000303313313131113331311133313111333131113333113313000000000009400000a9a4000000000000094110010000100001200000012000
0010110000000000022100000000000000000000000000000000000000000020000000000009400000a9a4000000000000021010010111000100200001002000
0000010000000000094101220221202102212021022120210221202121102220000000000004400000aaa4000000000000002200100110011121000011210000
00010000000000000442102001111011011110110111101101111011111012000000000000044000104a42000000000000000020002210212100000021000000
00000000000000000112121001010000010100000101000001010000010012000000000000000001000000000000000000000002000000020000000000000000
00000000000000000221000000000000000000000000000000000000000112000000000000000000000000000000000000000000022100000001120000000000
000000000000000000241010000000000000000000000000000000000000010000000000004a9200000940000000000000000000002410100000010000000000
00000000000000000009410000000000001000000000000000000000001120000000000000aaa400000940000000000000000000000941000011200001100000
00000000000000000009411000000000010000100000000000000000000120000000000000a9a400000940000000000000000000000941100001200000010000
00000000000000000002101001000000010111000000000000000000010020000000000000a9a400000940000000000000000000000210100100200010000000
00000000000000000000220010011000100110010000000000000000112100000000000000aaa400000440000000000000000000000022001121000001010000
000000000000000000000020202111020022102100000000000000002100000000000000004a4200000440000000000000000000000000202100000000000100
00000000000000010000000200022220000000020000000000000000000000000000000000000000000000000000000000000000000000020000000000000100
00000000000000000000000000000000000000000221000000011200000000000000000000000000000001000000000000000000000001000000000000000000
00000001000000000000000000000000000000000024101000000100000000000000000000000000000000100000000000000000000000000000000000000000
00000000101000000000000000000000000000000009410000112000000000000000000000000000000010010110000000000000000010000000000000000000
00000000000000000000000000000000000000000009411000012000000000000000000000000000000101000001000000000000000101000000000000000000
00000001001011000000000000000000000000000002101001002000000000000000000000000000011000001000000000000000011000000000000000000000
00000000000001000000000000000000000000000000220011210000000000000000000000000000000100000101000000000000000100000000000000000000
00000000000100000000000000000000000000000000002021000000000000000000000000000000110000000000010000000000110000000000000000000000
00000000000000000000000000000000000000000000000200000000000000000000000000000001000000000000010000000001000000000000000000000000
00000000000000000000000000000000001000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000001011000000000000000000000000000010110000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000010000100000000000000000000000000100001000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000001010000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000001000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000010001000000000000000000000000000100010000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000011000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002010101010000000000000000000000000101010100000000000000000000000001010101000000000000000000000000010101010100000000000000
0200000001010101000000010101010100000000010101010000000001010101010101000101010100000000010101010101000001010101000000000101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
00000000000000000000000000000000000000000000000000006c6d0000000000000000b80000bcbf7e6f7e7eb8b8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000005e5e5e5f000000000000b8b8b8b8b80000000000416d6c6d7c000000000000b80000206f7f6f8c8fb8b80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004f000000000000000000004f
000000848780808080a1000000b0000000000000848586876c416c848586858700002000b80000007f6f8cacbf8e8e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004a0000004f0000004a004c00000000004d0000
0000b8949790000091a000000000000000000000b4b5b6b76e416d949595959700000000b800007f7e6f9c8cad000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004f4c4f00004a4c004b4900004e000000480000
0000b894970000cd0000000000a10000000000006c6c6e6e6d416c949596959700000000b8007f6f7e8cbebfbcad9e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004900004a4849004e004a004c4b4d004900004c
00a0a0a0a00069790000000000a000000000007d6d6a40406a418494959595978800000000007e7e7e7f6f7f6f9c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000484b00490048004b4d4b0000004800484f4900
006b61737200444700000000a1a0a14100000084858740407a4194a49595969787000000886f7e6f6f417e6f6f9c9e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004a595a004f004a004a00494b4900004849
000072617100005788680000b3a0b34100009394959740407a4194959595959797a3008c8f7f8c8d8f418c8e8e8fbd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004a005800005c004a4b595a0048004a00494b00
00007172000079574547680000000041000000a4a5a78585868687a5a5949597a70000bcbf8dbcbebf41ac9eaebf000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000595a005900005c595b00005a00494b00595a00
000000710000446477744769000000410000000000a4a6a5a5a5a70000a4a6a700000000bcbdbf4200419caebf000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005800000000005958005c005c585c5a5900005b
0000000000000054470074476979444600000000000000003400000000000000000000000042005200419c9f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000590000005c000000
00005d5e5f136954770000744446474700000000000000b8b80000000000697968000000005200520041bcbf000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000595800005c0000595a0000005900005a0000
000044464646464700b8b800747677770000000000000000000000000000444747004300005200620041000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005a00000000000000000059005c000000000058
000074757655557700b8b80000747700b2000000000000000000000000000000000053430062000000418c8f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000595800005958000000000000585b005c00
00000000007477000000000000000000440000a20000a20000a200004446470000006353000000000041acaf8f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005a0000000000000000595b00590000000000
000000000000000000000000000000000000000000000000000000005455670000444747000000444741acbfaf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000580000005800000000000000000000
000000000000000069688800000000000000000000000000000000007455555050545657606060546747bcbebf000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005c000000000000
00886968681369694446475d5e5e5f6879698879000000000000000000545555555465677070706466570000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005800005900000000000000000000580000
00444645464646476455678080808046464446470000000000000000007476767574556578787855767700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005900000000000000005a0000000000000000
0074555577655555657777900000915455747577000000000000000000007477000064555555557700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000747777556555556790000000007465556700000000000000000000000000000074757675770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000007475777476757700004300000074757700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000005300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000005d635f00b800b80069790000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000444647004500450044470000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000074770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

