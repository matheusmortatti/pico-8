cart_change=entity:extend({
    collides_with={"player"},
    pt={[0]=0b1111111111111111.1,0b1101101111011011.1,0b0101101001011010.1,0b0.1},
    draw_order=7,
    hitbox=box(0,0,8,8),
    ll=0,
    cart={[127]="boss.p8",[126]="cave.p8",[125]="u1bg.p8"}
})

cart_change:spawns_from(127,126,125)

function cart_change:fadeout()
    self.ll=1
    if self.t>61 then
        load(self.cart[self.sprite])
    elseif self.t>60 then
        self.ll=3
    elseif self.t>30 then
        self.ll=2
    end
end

function cart_change:render()
    fillp(self.pt[self.ll])
    local p=level_index*128
    rectfill(p.x,p.y,p.x+128,p.y+128,0)
    fillp()
end

function cart_change:collide(e)
    if (self.state!="fadeout")self:become("fadeout")
end