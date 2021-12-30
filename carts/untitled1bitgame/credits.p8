pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

#include template.lua
#include structural.lua
#include fade.lua

messages=entity:extend({
    lines=
      {
        {
          {"the balance of time","has been restored"},
          120,0
        },
        {
          {"the gate has been sealed",
           "once again to keep",
           "time contained within it."},
          120,0	
        },
        {
          {"you come back home, place","your sword down and rest."},
          120,0
        },
        {
          {"the end"},
          120,0
        }
      },
    index=1
})

function messages:init()
end

function messages:update()
  self.lines[self.index][3]+=1
  if self.lines[self.index][3]>self.lines[self.index][2] then
    self.index+=1
    if self.index>#self.lines then
      e_add(fade({
        step=-1,ll=3,c=7
      }))

      self.done=true
    end
  end
end

function messages:render()
  local nlines=#self.lines[self.index][1]
  local starty=64-nlines*2
  for line in all(self.lines[self.index][1]) do
    print(line, 64-#line*2,starty,0)
    starty+=6
  end
  --print(self.lines[self.index][1],64-self.line_size*2,64,0)
end

------------------------------------
-- game state
------------------------------------

gamestate = {}

function gamestate.init()

  e_add(fade({
    step=-1,ll=3,c=7
  }))
  
  e_add(messages({

  }))
 
 reset_pal()
end

pft=time()
function gamestate.update()
 e_update_all()
 bkt_update()
 do_movement()
 do_collisions()
 p_update()

 local t_add=-(time()-pft)
 add_time(global_timer<10 and t_add*(global_timer*0.7/10+0.3) or t_add)
 global_timer=max(0, global_timer)
 global_timer=min(100,global_timer)
 pft=time()
end

function gamestate.draw()
 cls()

 rectfill(0,0,128,128,7)

 e_draw_all()
 p_draw_all()

  camera()
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
