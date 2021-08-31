------------------------------------
-- title screen state
------------------------------------

gamestate = {}

function gamestate.init()
    
  local has_save_file=cartdata("mortatti_u1bg")
  if not has_save_file then
      dset(0,3)
  end

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


 e_add(titleoption({
     pos=level_index*128+v(64,64),
     text=has_save_file and "continue" or "new game",
     select_func=function()
        e_add(fade({
            func=function()
                load("u1bg.p8", nil, "72,22")
            end
        }))
     end
 }))

 e_add(titleoption({
  pos=level_index*128+v(64,76),
  text="quit",
  select_func=function()
     e_add(fade({
         func=function()
             stop()
         end
     }))
  end
}))
 
 reset_pal()
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

  camera()
end