------------------------------------
-- game state
------------------------------------

gamestate = {}
safe_levels = {
  v(3,0),v(4,0),v(5,0)
}

if not cartdata("u1bg") then
  dset(0,1)
end

function gamestate.init()

  multiplier=dget(10)

  local str_pos=split(stat(6))
  for i=0,127 do
    for j=0,63 do
      if mget(i,j)==32 then
        level_index=v(flr(i/16),flr(j/16))
      end
    end
  end

  
  load_level()
  cm=cam(
    {
      pos=level_index*128
    }
  )
  e_add(cm)
  wm=worldmap({})
  e_add(wm)

  e_add(fade({
    step=-1,ll=3
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
 
 local is_safe=false
 for s in all(safe_levels) do
  if (s == level_index) is_safe=true
 end
 if is_safe==false then
  local t_add=-(time()-pft)
  add_time(global_timer<10 and t_add*(global_timer*0.7/10+0.3) or t_add)
  global_timer=max(0, global_timer)
  global_timer=min(100,global_timer)
end
pft=time()
end

function gamestate.draw()
 cls()

 e_draw_all()
 p_draw_all()

  camera()
  local st=tostr(flr(global_timer))
  local c=7
  if global_timer<5 then c=8 elseif global_timer<10 then c=9 end

  rectfill(1, 1, #st*4+3, 9, 0)
  rect(1, 1, #st*4+3, 9, c)
  print(st, 3, 3, c)
end