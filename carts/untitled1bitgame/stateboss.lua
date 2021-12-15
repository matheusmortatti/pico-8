------------------------------------
-- game state
------------------------------------

gamestate = {}

if not cartdata("u1bg") then
  dset(0,1)
end

function gamestate.init()

  multiplier=dget(10)
  for i=0,127 do
    for j=0,63 do
      if mget(i,j)==32 then
        level_index=v(flr(i/16),flr(j/16))
      end
    end
  end
  
  load_level()
  e_add(cam(
    {
      pos=level_index*128
    }
  ))

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
 update_invoke()

 local t_add=-(time()-pft)
 add_time(global_timer<10 and t_add*(global_timer*0.7/10+0.3) or t_add)
 global_timer=max(0, global_timer)
 global_timer=min(100,global_timer)
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

------------------------------------
-- func scheduler
------------------------------------

invoke_func = {}
function invoke(func,t,p)
  add(invoke_func,{func,0,t,p})
end

function update_invoke()
  for i=#invoke_func,1,-1 do
    invoke_func[i][2]+=1
    if invoke_func[i][2]>=invoke_func[i][3] then
      invoke_func[i][1](invoke_func[i][4])
      del(invoke_func,invoke_func[i])
    end
  end
end