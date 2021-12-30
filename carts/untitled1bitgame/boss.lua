------------------------------------
-- boss
------------------------------------

enemy_list={charger, blob, laserdude, bat}

boss=enemy:extend({
    state="idle",
    inv_t=6*30,
    health=10,
    spawn_time=1,
    draw_order=2,
    cd=300,
    maxvel=4,
    basevel=4,
    fric=10,
    inv_t=1*30,
    difficulty_level=0,
    wave_index=0,
    wave_levels={
        {v(7,0)},
        {v(6,1),v(7,1)},
        {v(6,0), v(5,0),v(5,1)}
    },
    open_levels={
        v(0,0),
        v(1,0),
        v(2,0)
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
        --self.invincible=false
        self.ht=0
    end

    self:set_vel()
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
    for c in all(self.enemy_spawn_class) do
        local e,p,t=c[1],c[2],c[3]
        local x,y=p.x,p.y
        local mp=v(x/8, y/8)
        
        local e_inst=e({
            pos=mp*8,
            vel=zero_vector(),
            map_pos=mp,
            sprite=t,
            inst=e
        })

        e_add(e_inst)
        add(self.spawn_list, e_inst)

        add_explosion(e_inst.pos,2,2,2,-3,-1,7,9,0)

        if (e==bat) e_inst.attack_dist=10000
        if (e==laserdude)e.sprite=10
    end
end

function boss:delete_entities()
    for e in all(self.spawn_list) do
        e.done=true
    end
    for e in all(self.entity_list) do
        e.done=true
    end
    self.entity_list={}
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
        if e.inst!=spike and e.inst!=slowdown and e.done!=true then 
            has_killed_everyone=false
        end
    end

    if self.t==30 then
        self:spawn_enemies()
    elseif self.t>120 and has_killed_everyone then
        self:become("waves_move_init")
    end
end

function boss:waves_move_init()
    self:reset()

    if (self.difficulty_level>#self.wave_levels) self:become("open") return

    self.wave_index+=1
    if self.wave_index>#self.wave_levels[self.difficulty_level] then
        self:become("open") 
        return
    end
    
    local li=self.wave_levels[self.difficulty_level][self.wave_index]
    self.tile_list,self.enemy_spawn_class,self.player_pos, self.target_pos=spawn_level(li.x,li.y)
    
    self.co_move_to = cocreate(move_to)
    self:become("waves_move_update")
end

function boss:waves_move_update()
    coresume(self.co_move_to,self,self.target_pos)
    if costatus(self.co_move_to) == 'dead' then
        self:become("fadeout")
        self.next_state="waves_update"
    end
end

------------------------------------
-- open state
------------------------------------

function boss:open()
    self:become("open_move_init")
    self.invincible=false
end

function boss:open_move_init()
    self:reset()

    local li=self.open_levels[min(self.difficulty_level,#self.open_levels)]
    self.tile_list,self.enemy_spawn_class,self.player_pos, self.target_pos=spawn_level(li.x,li.y)
    
    self.co_move_to = cocreate(move_to)
    self:become("open_move_update")
end

function boss:open_move_update()
    coresume(self.co_move_to,self,self.target_pos)
    if costatus(self.co_move_to) == 'dead' then
        self:become("fadeout")
        self.next_state="open_update"
    end
end

function boss:open_update()
    if self.t==1 then self:spawn_enemies() end
    -- stay here until it gets attacked
end

------------------------------------
-- direct attack state
------------------------------------

function boss:direct_attack()
    self.direct_attack_counter=-1
    self.co_move_to = cocreate(move_to)
    
    self:reset()
    
    self.tile_list,self.enemy_spawn_class,self.player_pos, self.target_pos=spawn_level(4,1)
    add(self.enemy_spawn_class,{spike,self.player_pos,116})
    self:become("direct_attack_prepare")
end

function boss:direct_attack_prepare()
    coresume(self.co_move_to,self,self.target_pos)
    if costatus(self.co_move_to) == 'dead' then
        self:become("fadeout")
        self.next_state="direct_attack_decide_attack"
    end
end

function boss:direct_attack_decide_attack()
    self.direct_attack_counter+=1

    if (self.direct_attack_counter>=3) self:become("waves") return

    if #self.enemy_spawn_class>0 and rnd(1)>0.7 then
        self:become("direct_attack_spawn_spikes")
    else
        self:become("direct_attack_aim_init")
    end
end

function boss:direct_attack_spawn_spikes()
    if self.t==1 then
        self:spawn_enemies()
        local n=4
        for i=0,n do
            local s=self.spawn_list[flr(rnd(#self.spawn_list)+1)]
            s.done=true
            del(self.spawn_list, s)
        end

        for e in all(self.spawn_list) do
            e.low_t=0 e.mid_t=90 e.high_t=1000
        end
    end

    if self.t>150 then
        self:delete_entities()
        self:become("direct_attack_decide_attack")
    end
end


function boss:direct_attack_aim_init()
    self.co_move_to = cocreate(move_to)
    self.initial_pos=self.pos:copy()
    self:become("direct_attack_aim")
end

function boss:direct_attack_aim()
    coresume(self.co_move_to,self,v(scene_player.pos.x,32),15)
    if costatus(self.co_move_to) == 'dead' then
        self:become("direct_attack_shoot")
        self.laser=e_add(laser({pos=self.pos+v(0,8)}))
    end
end

function boss:direct_attack_shoot()
    self.laser.pos=self.pos+v(0,8)
    if self.t==1 and self.difficulty_level>=2 then
        self.maxvel=1
        self.dir.x=sign(scene_player.pos.x-self.pos.x)
    end
    if self.t%30==0 then 
        self.dir=zero_vector()
        self.laser.done=true
        self:become("direct_attack_decide_attack")
    end
end

------------------------------------
-- END direct attack state
------------------------------------

function boss:dying()
    if self.t%10==0 then
        for i=1,3 do
            e_add(smoke({
                pos=v(self.pos.x+rnd(8), self.pos.y+rnd(8)),
                c=7,r=rnd(2)+3,v=0.3
            }))
            shake=2
        end
    end

    if self.t==90 then
        local f = e_add(fade({spd=10, c=7}))
        f.func=function()
            load("credits.p8")
            return nil
        end
    end
end

function boss:fadeout()
    local f = e_add(fade({spd=5}))
    f.func=function()
        scene_player.pause=true
        invoke(function(f) 
            scene_player.pause=false

            scene_player.pos=self.player_pos
            self.entity_list=draw_tiles(self.tile_list)

            e_add(fade({
                step=-1,ll=3,spd=5
            }))

            f.done=true
        end,30,f)
        return nil
    end
    self.cd=60
    self:become("cooldown")
end

function boss:cooldown()
    if (self.t>self.cd) self:become(self.next_state)
end

function boss:hit_reaction()
    self.invincible=true
    self.difficulty_level+=1
    self:reset()
    self:become("direct_attack")
    if (self.difficulty_level>3) self:become("dying")
end

function boss:reset()
    self:delete_entities()
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

function boss:collide(e) end

------------------------------------
-- helper functions
------------------------------------

function spawn_level(lx,ly)
    local tx,ty=lx*16+1,ly*16+2
 
    local enemy_spawn_class={}
    local tile_list={}
    local player_pos=nil
    for i=0,13 do
        for j=0,12 do
            local t=mget(tx+i,ty+j)
            local sx,sy=level_index.x*16+1+i,level_index.y*16+2+j
            local p=v(sx*8,sy*8)
            local eclass=entity.spawns[t]
            if eclass then
                add(enemy_spawn_class,{eclass,p,t})
            elseif t==33 then
                player_pos=p
            elseif t==128 then
                boss_pos=p
            else
                add(tile_list, {sx,sy,t})
            end
        end
    end
    return tile_list,enemy_spawn_class,player_pos,boss_pos
end

function draw_tiles(tile_list)
    local entity_list={}
    for ti in all(tile_list) do
        local mpos=v(ti[1], ti[2])
        mset(mpos.x, mpos.y, ti[3])
        local eclass=entity.spawns[ti[3]]
        if eclass then
            local e=eclass({
                pos=mpos*8,
                vel=zero_vector(),
                sprite=ti[3],
                map_pos=mpos
            })
            add(entity_list, e)
            e_add(e)
        end
    end

    return entity_list
end

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

laser=enemy:extend({
    hitbox=box(0,0,8,200),
    state="charging",
    c_tile=false
})

function laser:init()
    local f=function(s) self:become(s) end
    invoke(f, 10, "shooting")
    invoke(f, 20, "cooldown")
end

function laser:shooting()
    local p=c_get_entity(scene_player)
    if p.b:overlaps(self.hitbox:translate(self.pos))then
        enemy_collide(self, scene_player)
    end
end

function laser:render()
    local x,y=self.pos.x,self.pos.y
    if self.state=="charging" or self.state=="cooldown" then
        if self.t%2 == 1 then
            rectfill(x+3, y, x+4, y+200, 8)
        end
    elseif self.state=="shooting" then
        rectfill(x+3, y, x+4, y+200, 8)
        rectfill(x, y, x+2, y+200, 9)
        rectfill(x+5, y, x+7, y+200, 9)
    end
end