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
          {"the flow of time","has been restored"},
          120,0
        },
        {
          {"the gate has been sealed",
           "once again to keep",
           "the sands of time",
           "from getting into the",
           "wrong hands."},
          180,0	
        },
        {
          {"you come back home, place","your sword down and rest."},
          120,0
        }
      },
    index=1
})

function messages:update()
  self.lines[self.index][3]+=1
  if btnp(4) or btnp(5) or self.lines[self.index][3]>self.lines[self.index][2] then
    self.index+=1
    if self.index>#self.lines then
      e_add(fade({
        step=-1,ll=3,c=7
      }))

      self.done=true
      e_add(credits({}))
    end
  end
end

function messages:render()
  render_text_middle(self.lines[self.index][1])
end

function render_text_middle(lines,offset)
  local nlines=#lines
  local off=offset or 0
  local starty=64-nlines*2+off
  for line in all(lines) do
    print(line, 64-#line*2,starty,0)
    starty+=6
  end
end

credits=entity:extend({
  text={
    "a game by:", "",
    "matheus mortatti",
    "", "", "", "", "", "", "", "", "", "",

    "game programming:",
    "",
    "matheus mortatti",
    "","",

    "art:",
    "",
    "matheus mortatti",
    "","",

    "level design:",
    "",
    "matheus mortatti",
    "", "",

    "playtesting:",
    "",
    "esdras chaves"
  },
  scroll=0
})

function credits:render()
  local nlines=#self.text
  local spd=(btn(4) or btn(5)) and 1 or 5
  if self.t>120 and self.t%spd==0 then self.scroll+=1 end
  render_text_middle(self.text,nlines*2-6-self.scroll)

  if self.scroll>64+nlines*6 then
    e_add(the_end({}))
    self.done=true
  end
end

the_end=entity:extend({})

function the_end:init()
  e_add(fade({
        step=-1,ll=3,c=7
      }))
end

function the_end:render()
  render_text_middle({"the end."})

  if self.t>90 and self.t%60>30 then
    print("❎",62,96,0)
  end

  if self.t>90 and (btnp(5) or btnp(4)) then
    self.done=true
    load("titlescreen.p8")
  end
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
