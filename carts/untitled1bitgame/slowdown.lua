-------------------------------
-- entity: slowdown
-------------------------------

slowdown=entity:extend({
    tags={"slowdown"},
    collides_with={"player","enemy"},
    draw_order=1
  })
  
  slowdown:spawns_from(56)
  
  function slowdown:collide(e)
    if e.basevel then
      e.maxvel=e.basevel/2
    end
  end