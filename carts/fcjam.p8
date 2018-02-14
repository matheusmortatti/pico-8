pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

function deep_copy(obj)
 if (type(obj)~="table") return obj
 local cpy={}
 setmetatable(cpy,getmetatable(obj))
 for k,v in pairs(obj) do
  cpy[k]=deep_copy(v)
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
    t=0,state="idle",
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
-- entity: enemy
-------------------------------

enemy=entity:extend({
  state="nothing",
  collides_with={"player","enemy"},
  tags={"enemy"}
})

function enemy:collide(e)
  return c_push_out
end

-------------------------------
-- entity: player
-------------------------------

player=entity:extend({
  state="idle", vel=v(0,0),
  collides_with={"enemy"},
  tags={"player"}
})

function player:idle()
  if btn(5) then self.done = true end
  self.vel=v(0,0)
  if btn(0) then self.vel.x = -1 end
  if btn(1) then self.vel.x =  1 end
  if btn(2) then self.vel.y = -1 end
  if btn(3) then self.vel.y =  1 end
 end

function player:collide(e)
  
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
-- collision system
-------------------------------

function do_movement()
  for t,v in pairs(entities) do       
      for e in all(v) do
        if e.vel then e.pos+=e.vel end        
      end
    end
end

-------------
-- Buckets
-------------

c_bucket = {}

function bkt_pos(e)
  local x,y=e.pos.x,e.pos.y
  return flr(shr(x,4)),flr(shr(y,4))
end

-- Add entity to all the indexes
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
  for t,v in pairs(entities) do       
      for e in all(v) do
        bkt_update_entity(e)
      end
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
    bkt_update()
  	for t,v in pairs(entities) do       
      for e in all(v) do
        collide(e)
      end
    end
end

function collide(e)
  if not e.collides_with then return end
  if not e.hitbox then return end

  local ec={}
  ec.e=e
  ec.b=e.hitbox:translate(e.pos)

  -------------------------
  -- Entity Collision
  -------------------------
  for tag in all(e.collides_with) do
    --local bc=bkt_get(tag,e.bkt.x,e.bkt.y)
    for o in c_potentials(e,tag) do --all(entities[tag]) do
      -- create an object that holds the entity
      -- and the hitbox in the right position
      local oc={}
      oc.b=o.hitbox:translate(o.pos)
      oc.e=o
      -- call collide function on the entity
      -- that e collided with
      if o~=e and ec.b:overlaps(oc.b) then
        if oc.e.collide then 
          local func,arg=oc.e:collide(e)
          if func then
            func(oc,ec,arg)
          end
        end
      end

    end
  end

  -------------------------
  -- Tile Collision
  -------------------------

  -- Do not collide if it's not set to
  if (not e.c_tile) return

  local pos=tile_flag_at(ec.b, 1)

  for p in all(pos) do
    local oc={}
    oc.b=box(p.x,p.y,p.x+8,p.y+8)

    -- only allow pushing to empty spaces
    local dirs={v(-1,0),v(1,0),v(0,-1),v(0,1)}
    local allowed={}
    for i=1,4 do
      local np=v(p.x/8,p.y/8)+dirs[i]
      allowed[i]= not is_solid(np.x,np.y)
    end

    c_push_out(oc, ec, allowed)
  end

end

function tile_at(cel_x, cel_y)
	return mget(cel_x, cel_y)
end

function is_solid(cel_x,cel_y)
  return fget(mget(cel_x, cel_y),1)
end

function tile_flag_at(b, flag)	
  local pos
	for i=flr(b.xl/8), flr((b.xr-1)/8) do
		for j=flr(b.yt/8), flr((b.yb-1)/8) do
			if(fget(tile_at(i, j), flag)) then
        if not pos then pos={} end
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
 ec.e.pos+=sepv
 if ec.e.vel then
  local vdot=ec.e.vel:dot(sepv)
  if vdot<0 then
   if sepv.y~=0 then ec.e.vel.y=0 end
   if sepv.x~=0 then ec.e.vel.x=0 end
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


--------------------
-- entity handling
--------------------

entities = {}

-- adds entity to all entries
-- of the table indexed by it's tags
function e_add(e)  
  for tag in all(e.tags) do    
    if not entities[tag] then
      entities[tag] = {}
    end
    add(entities[tag], e)
  end
end

function e_remove(e)
  for tag in all(e.tags) do    
    del(entities[tag], e)
  end
end

-- loop through all entities and
-- update them based on their state
function e_update_all()  
  for t,v in pairs(entities) do       
    for e in all(v) do        
      if e[e.state] then
        e[e.state](e)
      end
      e.t+=1

      if e.done then
        e_remove(e)
      end
    end
  end  
end

function e_draw_all()
  for t,v in pairs(entities) do      
      for e in all(v) do        
        e:render()
      end
    end
end

function spr_render(e)
  spr(e.sprite, e.pos.x, e.pos.y)
end

function _init()
  e_add(player({
    state="idle",
    sprite=1,pos=v(56,10),
    hitbox=box(0,0,8,8),
    c_tile=true
  }))

  e_add(enemy({
    sprite=1,pos=v(64,64),
    hitbox=box(0,0,8,8),
    c_tile=true
  }))  
end

function _update60()    
  e_update_all()
  do_movement()
  do_collisions()
end

function _draw()
  cls()
  print("cpu: " .. stat(1) .. " mem: " .. stat(0))
  map(0, 0, 0, 0, 16, 16)
  e_draw_all()
end
__gfx__
00000000888888889999999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888889999999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700888888889999999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000888888889999999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000888888889999999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700888888889999999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888889999999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888889999999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000020202020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000020202020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
