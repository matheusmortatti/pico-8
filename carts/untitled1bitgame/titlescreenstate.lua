------------------------------------
-- title screen state
------------------------------------

gamestate = {}

function gamestate.init()
    
  has_save_file=cartdata("u1bg")
  if not has_save_file then
    reset_cartdata()
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
 
 load_main_options()
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

function load_main_options()
  if has_save_file then
    e_add(titleoption({
      pos=level_index*128+v(64,64),
      text="continue",
      select_func=function()
        e_add(fade({
            func=function()
                load("u1bg.p8", nil, "72,22")
                return true
            end
        }))
      end
    }))
  end

  e_add(titleoption({
    pos=level_index*128+v(64,80),
    text="new game",
    select_func=function()
      load_ng_options()
    end
  }))

  e_add(titleoption({
    pos=level_index*128+v(64,96),
    text="quit",
    select_func=function()
      e_add(fade({
          func=function()
              stop()
          end
      }))
    end
  }))
end

function load_ng_options()
  e_add(titleoption({
    pos=level_index*128+v(64,48),
    text="easy",
    select_func=function()
      e_add(fade({
          func=function()
            reset_cartdata()
            dset(10,1.3)
            load("u1bg.p8", nil, "72,22")
          end
      }))
    end
  }))

  e_add(titleoption({
    pos=level_index*128+v(64,64),
    text="normal",
    select_func=function()
      e_add(fade({
          func=function()
            reset_cartdata()
            dset(10,1.1)
            load("u1bg.p8", nil, "72,22")
          end
      }))
    end
  }))

  e_add(titleoption({
    pos=level_index*128+v(64,80),
    text="hard",
    select_func=function()
      e_add(fade({
          func=function()
            reset_cartdata()
            dset(10,0.8)
            load("u1bg.p8", nil, "72,22")
          end
      }))
    end
  }))

  e_add(titleoption({
    pos=level_index*128+v(64,96),
    text="back",
    select_func=function()
      load_main_options()
    end
  }))
end

function reset_cartdata()
  dset(0,1)
  for i=1,63 do
    dset(i,0)
  end
end