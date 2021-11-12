------------------------------------
-- boss
------------------------------------

enemy_list={charger, blob, laserdude, bat}

boss=enemy:extend({
    state="idle",
    inv_t=6*30,
    health=10,
    spawn_time=1,
    obstacle_list={},
    cd=300,
    maxvel=4,
    basevel=4,
    fric=10,
    inv_t=1*30
})

boss:spawns_from(1)

function boss:init()
    
end

function boss:update()
    self.player_boss_dir=(scene_player.pos-self.pos):norm()
    -- invincibility time
    if (self.invincible) self.ht+=1

    self.hit=false
    if self.ht > self.inv_t then
        self.invincible=false
        self.ht=0
    end

    self:set_vel()
    for e in all(self.obstacle_list) do
        e.timer+=1
        if(e.timer>e.deadline or (self.hit and self.t>self.ht)) then
            e.ent.done=true
            del(self.obstacle_list,e)

            for i=1,2 do
                p_add(smoke(
                {
                    pos=v(
                        e.ent.pos.x+4+rnd(2)-1,
                        e.ent.pos.y+2+rnd(2)-1),
                    c=rnd(1)<0.5 and 7 or 9
                }
                ))
            end
        end
    end
end

function boss:spawn_level(lx,ly)
    local tx,ty=lx*16+1,ly*16+2
 
    self.enemy_spawn_pos={}
 
    for i=0,13 do
        for j=0,12 do
            local t=mget(tx+i,ty+j)
            local sx,sy=level_index.x*16+1+i,level_index.y*16+2+j
            if t==19 then
                add(self.enemy_spawn_pos,{sx*8,sy*8})
            elseif t==33 then
                scene_player.pos=v(sx*8,sy*8)
            else
                mset(sx,sy,t)
            end
        end
    end
end

function boss:reset_level()
    for i=0,13 do
        for j=0,12 do
            local sx,sy=level_index.x*16+1+i,level_index.y*16+2+j
            mset(sx,sy,0)
        end
    end
end

function boss:spawn_enemies()
    for p in all(self.enemy_spawn_pos) do
        local x,y=p[1],p[2]
        local mp=v(x/8, y/8)
        local e=enemy_list[flr(rnd(#enemy_list)+1)]
        
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

function boss:delete_enemies()
    for e in all(self.spawn_list) do
        e.done=true
    end
    self.spawn_list={}
end

function boss:fadeout()
    local f = e_add(fade({spd=5}))
    f.func=function()
        scene_player.pause=true
        invoke(function(f) 
            scene_player.pause=false

            local li=level_index+v(1,0)
            self:spawn_level(li.x,li.y)

            e_add(fade({
                step=-1,ll=3,spd=5
            }))

            f.done=true
        end,30,f)
        return nil
    end
    self:become("wave_update")
end

------------------------------------
-- wave state
------------------------------------


function boss:wave_update()
    local has_killed_everyone=true
    for e in all(self.spawn_list) do
        if e.done!=true then 
            has_killed_everyone=false
        end
    end

    if has_killed_everyone and not self.waiting_spawn then
        self.spawn_list={}
        self.waiting_spawn=true
        invoke(function() self.waiting_spawn=false self:spawn_enemies() end, 120)
    end
end

------------------------------------
-- direct attack state
------------------------------------

function boss:direct_attack_prepare_init()
    self.direct_attack_counter=0
    self.co_move_to = cocreate(move_to)
    self:become("direct_attack_prepare")
end

function boss:direct_attack_prepare()
    coresume(self.co_move_to,self,level_index*128+v(64,32))
    if costatus(self.co_move_to) == 'dead' then
        self:become("direct_attack_aim_init")
    end
end

function boss:direct_attack_aim_init()
    if (self.direct_attack_counter>=3) self:become("choose_pos") return

    self.co_move_to = cocreate(move_to)
    self:become("direct_attack_aim")
end

function boss:direct_attack_aim()
    coresume(self.co_move_to,self,v(scene_player.pos.x,32))
    if costatus(self.co_move_to) == 'dead' then
        self:become("direct_attack_shoot")
    end
end

function boss:direct_attack_shoot()
    if (self.t%100==0) self.direct_attack_counter+=1 self:become("direct_attack_aim_init")
end

function boss:render_direct_attack_shoot()
    line(self.pos.x+4, self.pos.y+4,self.pos.x+4, self.pos.y+100)
end

------------------------------------
-- END direct attack state
------------------------------------

function boss:cooldown()
    if (self.t>self.cd) self:become(self.next_state)
end

function boss:choose_pos()
    local positions={
        v(4,4),v(4,11),v(11,4),v(11,11)
    }
    self.target_pos=positions[flr(rnd(#positions)+1)]*8+level_index*128
    self:become("move_init")
end

function boss:move_init()
    self.co_move_to = cocreate(move_to)
    self:become("move_update")
end

function boss:move_update()
    coresume(self.co_move_to,self,self.target_pos)
    if costatus(self.co_move_to) == 'dead' then
        self:become("fadeout")
    end
end

function move_to(inst,target_pos)
    printh(target_pos:str())
    local s=0
    while s>=0 do
        local last_dir=inst.dir
        inst.dir=(target_pos-inst.pos):norm()
        s=inst.dir.x*last_dir.x+inst.dir.y*last_dir.y
        yield()
    end

    inst.pos=target_pos
    inst.dir=zero_vector()
end

function boss:hit_reaction()
    self.invincible=true
    self:delete_enemies()
    self:reset_level()
    self:become("direct_attack_prepare_init")
end

function boss:render()
    shared_render(self)
    if self.invincible then
        circ(self.pos.x+4,self.pos.y+4,10,9)
    end

    local draw_state="render_"..self.state
    if (self[draw_state])self[draw_state](self)
end