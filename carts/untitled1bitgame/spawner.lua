-------------------------------
-- entity: spawner
-------------------------------

enemy_list={charger, blob, laserdude, bat}

spawner=enemy:extend({
  collides_with={"player"},
  state="spawning",
  maxvel=2,
  c_tile=true,
  spawn_time=10*30,
  svel=0.2,
  spawn_number=2,
  spawn_limit=5,
  spawn_list={}
})

spawner:spawns_from(45)

function spawner:cooldown()
  self:become("spawning")
end

function spawner:spawning()
  self:manage_spawn_list()
  if self.t>=self.spawn_time then
    if #self.spawn_list < self.spawn_limit then
      self:spawn()
    end
    self:become("cooldown")
  end
end

function spawner:spawn()
    for i=1,self.spawn_number do
        local dirs={
            v(-1,0),v(1,0),v(0,-1),v(0,1),
            v(-1,-1),v(1,1),v(1,-1),v(-1,1)}
        local mp=v(self.pos.x/8, self.pos.y/8)
        local e=enemy_list[flr(rnd(#enemy_list)+1)]

        mp+=dirs[flr(rnd(#dirs)+1)]
        
        local e_inst=e({
            pos=mp*8,
            vel=zero_vector(),
            map_pos=mp
        })
        e_add(e_inst)
        add(self.spawn_list, e_inst)

        add_explosion(e_inst.pos,2,2,2,-3,-1,7,9,0)

        if (e==bat) e_inst.attack_dist=10000
        if (e==laserdude)e.sprite=10
    end
end

function spawner:manage_spawn_list()
  for e in all(self.spawn_list) do
    if e.done then
      del(self.spawn_list, e)
    end
  end
end