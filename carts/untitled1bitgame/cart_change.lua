cart_change=entity:extend({
    collides_with={"player"},
    hitbox=box(0,0,8,8),
    ll=0,
    ppos=v(71,14),
    cart={[127]="boss.p8",[125]="u1bg.p8"}
})

cart_change:spawns_from(127,126,125)

function cart_change:collide(e)
    e_add(fade({
        func=function()
            load(self.cart[self.sprite],nil,self.ppos:str())
        end
    }))
    scene_player.pause=true
    self.done=true
end