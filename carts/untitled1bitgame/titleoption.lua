------------------------------------
-- title option
------------------------------------

titleoption=dynamic:extend({
    hitbox=box(0,0,8,8),
    collides_with = {"player"},
    c_tile=false,
    state="movein",
    maxvel=4,
    basevel=4,
    acc=0.2,
    fric=0.4,
    dir=v(-1,0),
    text="default",
    draw_order=1,
    select_func=nil
})

function titleoption:init()
    self.target_pos=self.pos:copy()
    self.pos=v(level_index.x*128+128,self.pos.y)

    local width=#self.text*4+2
    self.hitbox = box(-width/2, 0, width/2, 8)
end

function titleoption:update()
    if self.selected and (btnp(4) or btnp(5)) then
        if (self.select_func) self.select_func()
        self:become("moveout")
    end
end

function titleoption:moveout()
    self.dir=v(1,0)
    self:set_vel()
end

function titleoption:movein()
    self:set_vel()

    local dist=self.target_pos-self.pos
    local s=self.dir.x*dist.x+self.dir.y*dist.y
    if s<0 and dist:len()>10 then
        --printh("reached")
        self:become("comeback")
        --self.pos=self.target_pos
        self.dir*=-1
    end
end

function titleoption:comeback()
    self:set_vel()

    local dist=self.target_pos-self.pos
    local s=self.dir.x*dist.x+self.dir.y*dist.y
    if s<0 then
        --printh("reached")
        self:become("idle")
        --self.pos=self.target_pos
        self.vel=zero_vector()
        self.dir=zero_vector()
    end
end

function titleoption:collide(e)
    self.selected=true
end

function titleoption:end_collision(e)
    self.selected=false
end

function titleoption:render()
    local st=self.text
    local width=#st*4+2
    local c=7
    local x,y=self.pos.x-width/2, self.pos.y
    rectfill(x, y, width+x, 8+y, 0)
    rect(x, y, width+x, 8+y, c)
    print(st, x+2, y+2, c)

    if self.selected then
        print("➡️",x-8,y+2,c)
    end
end