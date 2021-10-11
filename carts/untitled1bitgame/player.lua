------------------------------------
-- e_player
------------------------------------

player=dynamic:extend({
    state="walking", vel=zero_vector(),
    collides_with={"slowdown"},
    tags={"player"}, dir=v(1,0),
    hitbox=box(2,3,6,8),
    sprite=0,
    draw_order=3,
    fric=0.5,
    inv_t=30,
    ht=0,
    hit=false,
    dmg=1,
    has_swrd=false,
    sword_upgrade=false,
    basevel=1,
    lr=32,
    persistent=true
   })
   
   player:spawns_from(32)
   
   function player:init()
    self.last_dir=v(1,0)
    self.sword_upgrade=dget(2)==1 and true or false
    if (dget(3)==1) self:upgrade_movement()
    add(lightpoints, self)
   end
   
   function player:destroy()
    del(lightpoints, self)
   end
   
   function player:update()
    self.ht+=1
    if self.ht > self.inv_t then
     self.hit=false
     self.ht=0
    end
   
     if global_timer==0 and self.state!="dead" then
       self:become("dead") self.sprite=37
     end

     if self.t%15==0 and self.vel!=zero_vector() and self.movement_upgrade then
      for i=1,3 do
        p_add(smoke(
        {
            pos=v(
                self.pos.x+4,
                self.pos.y+7),
            c=rnd(1)<0.5 and 7 or 9,
            r=rnd(2)+0.2,v=0.2
        }
        ))
      end
     end
   end
   
   function player:walking()
    self.dir=zero_vector()

    if (self.pause) self.vel=zero_vector() return
   
    if self.hit and self.ht<self.inv_t/2 then self:set_vel() return end
   
    if btn(0) then self.dir.x = -1 end
    if btn(1) then self.dir.x =  1 end
    if btn(2) then self.dir.y = -1 end
    if btn(3) then self.dir.y =  1 end
   
    self:set_vel()
   
    -- correct diagonal movement
    if self.vel.x ~= 0 and self.vel.y ~= 0 then
     self.vel/=1.4
    end
   
    if (self.dir~=zero_vector()) self.last_dir=v(self.dir.x,self.dir.y)
   
    if btnp(4) then 
     self:become("attacking")
    end
    self.maxvel = self.basevel
   end
   
   function player:attacking()
    if not self.attk then
     local dir=self.last_dir.x~=0 and v(self.last_dir.x,0) or v(0, self.last_dir.y)
     self.attk=sword_attack(
       {
         pos=self.pos+dir*8,
         facing=dir,
         upg=self.sword_upgrade
       }
     )
     self.attk.dmg=self.dmg
     e_add(self.attk)    
    end
   
    self.vel=zero_vector()
    if self.attk.done then 
     self.attk=nil 
     self:become("walking")
    end
   end
   
   function player:dead()
     self.vel=zero_vector()
     if (self.t>30*5) run(stat(6))
   end
   
   function player:render()
    if (self.hit and self.t%6>3) pal(7,8)
   
     local st,flip,spd="idle",false,0.1
   
     if self.state=="dead" then
       self.sprite+=spd
       self.sprite=min(self.sprite,40)
     else
       st=self.vel==zero_vector() and "idle" or "walking"
       flip=false
       spd=st=="idle" and 0 or 0.15
       self.sprite=st=="idle" and 32 or 33
       self.sprite+=flr(self.t*spd)%4
     end
   
     if self.last_dir.x<0 then
       flip=true
     end
   
    spr(self.sprite, self.pos.x, self.pos.y, 1, 1, flip)
    pal(7,7)
   end
   
   function player:damage(dmg)
    dmg=self.sword_upgrade and dmg*1.2 or dmg
    if not self.hit then
      sleep=5
     p_add(ptext({
       pos=v(self.pos.x-10,self.pos.y),
       txt="-"..dmg,c=8
     }))
     self.ht=0
     self.hit=true
   
     return true
    end  
   end
   
   function player:upgrade_movement()
    self.basevel *= 1.3
    self.movement_upgrade=true
   end
   
   -------------------------------
   -- entity: sword_attack
   -------------------------------
   
   sword_attack=entity:extend(
   {
    lifetime=10,
    hitbox=box(0,0,8,8),
    tags={"attack"},
    collides_with={"enemy"},
    facing=v(1,0),
    dmg=1,
    sprite=3,
    draw_order=5
   })
   
   function sword_attack:init()
    if self.upg then
      add_explosion(self.pos,4,8,8,0,0,12,7,0)
    end
   end
   
   function sword_attack:update()
    self.flipx=self.facing.x==-1
    self.flipy=self.facing.y==1
   
    if self.facing.x ~= 0 then self.sprite=3 else self.sprite=4 end
    if self.t > self.lifetime then self.done=true end
   
    --if self.t>5 then self.hitbox=box(0,0,0,0) end
   end
   
   function sword_attack:render()  
    spr(self.sprite, self.pos.x, self.pos.y, 1, 1, self.flipx, self.flipy)
   
    local nf=v(abs(self.facing.y),abs(self.facing.x))
    local off=v(abs(self.facing.x),abs(self.facing.y))*4+v(4,4)
    local pos=self.pos+nf*2
    local t=3*self.lifetime/4
    if self.t >= t then
     self:draw_dit(self.t-t,self.lifetime/4,true)    
    end
   end
   
   function sword_attack:collide(e)
    if e:is_a("enemy") and not e.hit then
     local multiplier=self.upg and 1.3 or 1
     e:damage(self.dmg*multiplier)
     local allowed_dirs={
      v(-1,0)==self.facing,
      v(1,0)==self.facing,
      v(0,-1)==self.facing,
      v(0,1)==self.facing
     }
     return c_push_vel,{allowed_dirs,1}
    end
   end