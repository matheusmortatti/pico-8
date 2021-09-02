------------------------------------
-- game state
------------------------------------

gamestate = {}

if not cartdata("u1bg") then
  dset(0,1)
end

function gamestate.init()

  local str_pos=split(stat(6))
  if #str_pos==2 then
    local player_pos=v(str_pos[1],str_pos[2])
    level_index=v(flr(player_pos.x/16),flr(player_pos.y/16))

    scene_player=player({
      pos=player_pos*8,
      map_pos=player_pos,
    })

    e_add(scene_player)
  else
    for i=0,127 do
      for j=0,63 do
        if mget(i,j)==32 then
          level_index=v(flr(i/16),flr(j/16))
        end
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

 local t_add=-(time()-pft)
 add_time(global_timer<10 and t_add*(global_timer*0.7/10+0.3) or t_add)
 global_timer=max(0, global_timer)
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