fade=entity:extend({
    pt={[0]=0b1111111111111111.1,0b1101101111011011.1,0b0101101001011010.1,0b0.1,0b0.1},
    ll=0,
    func=nil,
    step=1,
    draw_order=7,
    spd=15,c=0
})

function fade:update()
    if self.t%self.spd==self.spd-1 then
        self.ll+=self.step
        if (self.ll==#self.pt or self.ll==-1) then
            if (self.func) self.done=self.func() self.func=nil
            if (self.done==false) self.done=true
        end
        self.ll=clamp(0,#self.pt-1,self.ll)
    end
end

function fade:render()
    fillp(self.pt[self.ll])
    local p=level_index*128
    rectfill(p.x,p.y,p.x+128,p.y+128,self.c)
    fillp()
end