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

 function vector:copy()
  return v(self.x,self.y)
 end

 function zero_vector()
  return v(0,0)
 end

-- creates a new vector with
-- the x,y coords specified
function v(x,y)
 return setmetatable({
  x=x,y=y
 },vector)
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

entity=object:extend(
  {
    t=0,
    persistent=false,
    spawns={},
    hitbox=box(0,0,8,8)
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
  if state~=self.state and self.state!="dead" then
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

function entity:is_in_any_state(...)
  for st in all({...}) do
    if self.state==st then
      return true
    end
  end
  return false
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
    basevel=1,
    acc=0.5,
    fric=0.5,
    vel=v(0,0),
    hit=false,
    c_tile=true,
    dir=v(0,0)
  })
  
function dynamic:set_vel()  
  local x,y=0,0
  if (self.vel.x<0 and self.dir.x>0) or
     (self.vel.x>0 and self.dir.x<0) or
     (self.dir.x==0) then     
    x=approach(self.vel.x,0,self.fric)
  else
    x=approach(self.vel.x,self.dir.x*self.maxvel,self.acc)
  end

  if (self.vel.y<0 and self.dir.y>0) or
     (self.vel.y>0 and self.dir.y<0) or
     (self.dir.y==0) then
    y=approach(self.vel.y,0,self.fric)
  else
    y=approach(self.vel.y,self.dir.y*self.maxvel,self.acc)
  end
  self.vel=v(x,y)
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

  for o in all(e.cf) do
    local oc=c_get_entity(o)
    if o~=e and 
       not ec.b:overlaps(oc.b) and
       e.end_collision then
      e:end_collision(o)
    end
  end

  ---------------------
  -- entity collision
  ---------------------
  e.cf = {}
  for tag in all(e.collides_with) do
    --local bc=bkt_get(tag,e.bkt.x,e.bkt.y)
    for o in  c_potentials(e,tag) do  --all(entities[tag]) do
      -- create an object that holds the entity
      -- and the hitbox in the right position
      local oc=c_get_entity(o)
      -- call collide function on the entity
      -- that e collided with
      if o~=e and ec.b:overlaps(oc.b) then
        add(e.cf,o)
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
  local l={}
  for e in all(entities) do
    if(e.is_a and e:is_a(t)) add(l,e)
  end

  return l
end

-- adds entity to all entries
-- of the table indexed by it's tags
function e_add(e)
  add(entities, e)
  e.cf={}

  local dr=e.draw_order or 3
  if (not r_entities[dr]) r_entities[dr]={}
  add(r_entities[dr],e)
  return e
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
  spr(e.sprite, e.pos.x, e.pos.y,1,1,e.flip)
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

function dist_vector(a,b)
  return v(a.x-b.x,a.y-b.y)
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
-- func scheduler
------------------------------------

-- invoke_func = {}
-- function invoke(func,t,p)
--   add(invoke_func,{func,0,t,p})
-- end

-- function update_invoke()
--   for i=#invoke_func,1,-1 do
--     invoke_func[i][2]+=1
--     if invoke_func[i][2]>=invoke_func[i][3] then
--       invoke_func[i][1](invoke_func[i][4])
--       del(invoke_func,invoke_func[i])
--     end
--   end
-- end

------------------------------------
-- boilerplate code
------------------------------------

state = nil
sleep=0

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
  if sleep==0 then
    --update_invoke()
    state.update()
  end
  sleep=max(0,sleep-1)
end

function _draw()
  state.draw()
end