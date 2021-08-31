------------------------------------
-- globals
------------------------------------

debug=false
global_timer = 15

-->8
-------------------------------
-- structural
-------------------------------

function reset_pal()
  pal()
  palt(0, false)
  palt(1, true)
end

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
level_index=v(0,0)

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

entity_map={}

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
     pos=v(b.x+x,b.y+y)*8,
     vel=v(0,0),
     sprite=blk,
     map_pos=v(b.x+x,b.y+y)
    })

    local em=tostr(b.x+x)..","..tostr(b.y+y)
    if not e.spawn_condition or 
       e:spawn_condition(entity_map[em]) then
      -- register the entity
      e_add(e)
    end


   if (e:is_a("player")) scene_player=e
    -- replace the tile
    -- with empty space
    -- in the map
    if (e.persistent) mset(b.x+x,b.y+y,0)
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
    draw_order=0,
    shk=v(0,0),
    persistent=true
  }
)

function cam:update()
  self.pos.x=approach(self.pos.x,level_index.x*128,self.spd.x)
  self.pos.y=approach(self.pos.y,level_index.y*128,self.spd.y)

  if (self.pos==level_index*128) remove_old()

  if shake > 0 then
    shk=v(rnd(1)<0.5 and 1 or -1,rnd(1)<0.5 and 1 or -1)
    shake-=1
  else
    shake=0
    shk=v(0,0)
  end

  if scene_player then
    local h=scene_player.hitbox
    local p=scene_player.pos
    local l_ind=v(flr((p.x+h.xl+(h.xr-h.xl)/2)/128),
                  flr((p.y+h.yt+(h.yb-h.yt)/2)/128))

    if level_index ~= l_ind then
      level_index=l_ind
      load_level()
    end
  end
end

function cam:render()  
  camera(self.pos.x+shk.x,self.pos.y+shk.y)
end

function remove_old()
  for e in all(old_ent) do
    if (not e.persistent) e_remove(e)
  end
  old_ent={}
end