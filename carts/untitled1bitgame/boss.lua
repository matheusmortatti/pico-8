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
    inv_t=1*30,
    difficulty_level=1,
    wave_index=0,
    wave_levels={
        {v(5,0),v(6,0),v(7,0)},
        {}
    }
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

function spawn_level(lx,ly)
    local tx,ty=lx*16+1,ly*16+2
 
    local enemy_spawn_pos={}
    local tile_list={}
    local player_pos=nil
    for i=0,13 do
        for j=0,12 do
            local t=mget(tx+i,ty+j)
            local sx,sy=level_index.x*16+1+i,level_index.y*16+2+j
            if t==19 then
                add(enemy_spawn_pos,{sx*8,sy*8})
            elseif t==33 then
                player_pos=v(sx*8,sy*8)
            elseif t==128 then
                boss_pos=v(sx*8,sy*8)
            else
                add(tile_list, {sx,sy,t})
            end
        end
    end
    return tile_list,enemy_spawn_pos,player_pos,boss_pos
end

function draw_tiles(tile_list)
    for ti in all(tile_list) do
        mset(ti[1], ti[2], ti[3])
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

------------------------------------
-- wave state
------------------------------------

function boss:waves()
    self.wave_index=0
    self:become("waves_move_init")
end

function boss:waves_update()
    local has_killed_everyone=true
    for e in all(self.spawn_list) do
        if e.done!=true then 
            has_killed_everyone=false
        end
    end

    if self.t==120 then
        self:spawn_enemies()
    elseif self.t>120 and has_killed_everyone then
        self:become("waves_move_init")
    end
end

function boss:waves_move_init()
    self:reset()

    self.wave_index+=1
    if self.wave_index>#self.wave_levels[self.difficulty_level] then
        self:become("direct_attack_prepare_init") 
        return
    end
    
    local li=self.wave_levels[self.difficulty_level][self.wave_index]
    self.tile_list,self.enemy_spawn_pos,self.player_pos, self.target_pos=spawn_level(li.x,li.y)
    
    self.co_move_to = cocreate(move_to)
    self:become("waves_move_update")
end

function boss:waves_move_update()
    coresume(self.co_move_to,self,self.target_pos)
    if costatus(self.co_move_to) == 'dead' then
        self:become("waves_fadeout")
    end
end

function boss:waves_fadeout()
    local f = e_add(fade({spd=5}))
    f.func=function()
        scene_player.pause=true
        invoke(function(f) 
            scene_player.pause=false

            scene_player.pos=self.player_pos
            draw_tiles(self.tile_list)

            e_add(fade({
                step=-1,ll=3,spd=5
            }))

            f.done=true
        end,30,f)
        return nil
    end
    self:become("waves_update")
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
    if (self.direct_attack_counter>=3) self:become("waves") return

    self.co_move_to = cocreate(move_to)
    self.initial_pos=self.pos:copy()
    self:become("direct_attack_aim")
end

function boss:direct_attack_aim()
    coresume(self.co_move_to,self,v(scene_player.pos.x,32),15)
    --coresume(self.co_move_to,self,self.initial_pos,v(scene_player.pos.x,32),0.2,300)
    if costatus(self.co_move_to) == 'dead' then
        self:become("direct_attack_shoot")
    end
end

function boss:direct_attack_shoot()
    if self.t==1 and self.difficulty_level>0 then
        self.maxvel=1
        self.dir.x=sign(scene_player.pos.x-self.pos.x)
    end
    if self.t%30==0 then 
        self.dir=zero_vector()
        self.direct_attack_counter+=1 
        self:become("direct_attack_aim_init")
    end
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

function boss:hit_reaction()
    self.invincible=true
    self:reset()
    self:become("direct_attack_prepare_init")
end

function boss:reset()
    self:delete_enemies()
    self:reset_level()
end

function boss:render()
    shared_render(self)
    if self.invincible then
        circ(self.pos.x+4,self.pos.y+4,10,9)
    end

    local draw_state="render_"..self.state
    if (self[draw_state])self[draw_state](self)
end

------------------------------------
-- helper functions
------------------------------------

function move_to(inst,target_pos,t)
    t=t or 30
    local s=0
    local init_pos=inst.pos:copy()
    local dir=(target_pos-init_pos):norm()
    while s<=t do
        local x0=init_pos.x-dir.x
        local x1=init_pos.x
        local x2=target_pos.x
        local x3=init_pos.x+dir.x

        inst.pos.x=cubic_lerp(x0,x1,x2,x3,s/t)

        local y0=init_pos.y-dir.y
        local y1=init_pos.y
        local y2=target_pos.y
        local y3=init_pos.y+dir.y

        inst.pos.y=cubic_lerp(y0,y1,y2,y3,s/t)
        s+=1

        yield()
    end

    inst.pos=target_pos
    inst.dir=zero_vector()
end

function cubic_lerp(y0,y1,y2,y3,mu)
    local mu2=mu*mu
    local a0=y3-y2-y0+y1
    local a1=y0-y1-a0
    local a2=y2-y0
    local a3=y1

   return(a0*mu*mu2+a1*mu2+a2*mu+a3);
end