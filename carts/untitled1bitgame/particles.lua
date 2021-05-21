-------------------------------
-- particles
-------------------------------

-------------------------------
-- smoke particle
-------------------------------

smoke=particle:extend(
  {
    c=7,
    v=0.1
  }
)

function smoke:init()
  self.vel=v(rnd(0.5)-0.25,-(rnd(1)+0.5))
  if not self.r then self.r=rnd(1)+1.5 end
end

function smoke:update()
  self.r-=self.v
  if self.r<=0 then self.done=true end
end

function smoke:render()
  circfill(self.pos.x, self.pos.y, self.r, self.c)
end

function add_explosion(pos,n,rnx,rny)
  for i=1,n do
    e_add(smoke({
      pos=v(pos.x+rnd(rnx or 4), pos.y+rnd(rny or 4)),
      c=rnd(1)<0.7 and 6 or 7
    }))
  end
  shake=3
end

-------------------------------
-- text particle
-------------------------------

ptext=particle:extend(
  {
    lifetime=20,
    txt="-1",
  }
)

function ptext:init()
  local vx=0
  if self.vh then vx=rnd(0.5)-0.5 end
  self.vel=v(vx,-(rnd(1)+0.5))
end

function ptext:update()
  if self.t > self.lifetime/3 then 
    self.vel=v(0,0) 
  end
end

function ptext:render()
  local offs={
    v(-1,0),v(1,0),v(0,-1),v(0,1),
    v(1,1),v(1,-1),v(-1,1),v(-1,-1),
  }
  for o in all(offs) do
    print(self.txt,self.pos.x+o.x,self.pos.y+o.y,0)
  end
  
  print(self.txt,self.pos.x,self.pos.y,self.c or 7)

  if self.t > 2*self.lifetime/3 then
    draw_dithered(
      (self.lifetime-self.t)/(2*self.lifetime/3),false,
      box(self.pos.x,self.pos.y,self.pos.x+4*#self.txt+2,self.pos.y+4))
  end
end