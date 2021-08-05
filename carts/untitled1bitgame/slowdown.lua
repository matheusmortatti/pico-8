-------------------------------
-- entity: slowdown
-------------------------------

slowdown=entity:extend({
    hitbox=box(0,0,8,8),
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