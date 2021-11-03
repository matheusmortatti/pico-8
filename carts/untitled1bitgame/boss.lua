------------------------------------
-- boss
------------------------------------

boss=spawner:extend({
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


function boss:cooldown()
    if (self.t>self.cd) self:become("spawn_obstacles")
end

function boss:choose_pos()
    local positions={
        v(4,4),v(4,11),v(11,4),v(11,11)
    }
    self.target_pos=positions[flr(rnd(#positions)+1)]*8+level_index*128
    self:become("move")
end

function boss:move()
    local last_dir=self.dir
    self.dir=(self.target_pos-self.pos):norm()
    local s=self.dir.x*last_dir.x+self.dir.y*last_dir.y
    if s<0 then
        self:become("fadeout")
        self.pos=self.target_pos
        self.dir=zero_vector()
    end
end

function boss:hit_reaction()
    self.invincible=true
    self:delete_enemies()
    self:reset_level()
    printh("here")
    self:become("choose_pos")
end

function boss:spawn_obstacles()
    if self.t==1 then
        self.sp=instance_patterns[flr(rnd(#instance_patterns)+1)]
        self.instantiate = cocreate(instantiate_pattern)
    end
    
    if self.t%60==0 then
        coresume(self.instantiate,self.sp,self.obstacle_list)
        shake+=2
    end

    if costatus(self.instantiate) == 'dead' then
        self:become("cooldown")
    end
end

function boss:render()
    shared_render(self)
    if self.invincible then
        circ(self.pos.x+4,self.pos.y+4,10,9)
    end
end

function instantiate_pattern(pattern, e_list)
    for j=1,#pattern do
        local pattern_list=split(pattern[j])
        for i=1,#pattern_list do
            local index=pattern_list[i]
            if (index==0) goto pattern_continue
            local instance=instances[index]
            
            local p=v((i-1)%16*8,flr((i-1)/16)*8)
            local e=instance["inst_func"](p+level_index*128)
            e_add(e)
            add(e_list, {ent=e,timer=0,deadline=instance["deadline"]})
            
            ::pattern_continue::
        end
        yield()
    end
end

function inst_spike(p)
    return spike(
        {
            pos=p,
            low_t=0,
            mid_t=30,
            high_t=4*60
        })
end

function inst_slowdown(p)
    return slowdown(
        {
            pos=p, 
            sprite=56,
        })
end   

function inst_pot(p)
    return pot(
        {
            pos=p,
        })
end

------------------------------------
-- instance pattern
------------------------------------

instances = {
    {inst_func=inst_spike,deadline=300},
    {inst_func=inst_slowdown,deadline=300},
    {inst_func=inst_pot,deadline=300}
}

instance_patterns={
    {
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"..
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"..
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"..
        "0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,"..
        "0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,"..
        "0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,"..
        "0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,"..
        "0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,"..
        "0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,"..
        "0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,"..
        "0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,"..
        "0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,"..
        "0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,"..
        "0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,"..
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"..
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0"
        ,
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"..
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"..
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"..
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"..
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"..
        "0,0,0,0,2,3,2,3,2,3,2,3,0,0,0,0,"..
        "0,0,0,0,3,0,0,0,0,0,0,2,0,0,0,0,"..
        "0,0,0,0,2,0,0,0,0,0,0,3,0,0,0,0,"..
        "0,0,0,0,3,0,0,0,0,0,0,2,0,0,0,0,"..
        "0,0,0,0,2,0,0,0,0,0,0,3,0,0,0,0,"..
        "0,0,0,0,3,0,0,0,0,0,0,2,0,0,0,0,"..
        "0,0,0,0,2,3,2,3,2,3,2,3,0,0,0,0,"..
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"..
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"..
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"..
        "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0"
        ,
    }
}

------------------------------------
-- pot
------------------------------------

pot=entity:extend({
    hitbox=box(0,0,8,8),
    state="whole",
    draw_order=1,
    collides_with={"player","attack","enemy"},
    sprite=17
})

function pot:collide(e)
    if (self.t==0) self.done=true
    if self.state=="whole" then
        if e:is_a("attack") then
            self:become("broken")
            self.sprite+=1
        else
            return c_push_out
        end
    end
end
