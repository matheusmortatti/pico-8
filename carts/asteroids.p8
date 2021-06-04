pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

asteroid_controller= {
	init=function(self)
		self.vel=4
		self.scale=0
		self.e={}
	end,
	update=function(self)
		if self.t%60==0 then
			if rnd(1)<0.2 then
				create_entity(asteroid_small,rnd(128),rnd(128))
			else
				create_entity(asteroid_large,rnd(128),rnd(128))
			end
		end
	end,
	draw=function(self)
		
	end
}

bullet={
	init=function(self)
		self.vel=4
		self.scale=0.1
	end,
	update=function(self)
		local sn,cs=sin(self.ang),cos(self.ang)
		self.posx+=cs*self.vel
		self.posy+=sn*self.vel

		if self.t > 60 then
			destroy_entity(self)
		end
	end,
	draw=function(self)
		pset(self.posx,self.posy,7)
	end,
	on_collision=function(self,e)
		if (e.tag!="asteroid") return

		if hit_entity(e,1) then
			score+=e.points
		end
		destroy_entity(self)
	end
}

asteroid_large_1={
	{-1,0.5},
	{-1,-0.5},
	{-0.5,-1},
	{0.5,-0.5},
	{1,-0.25},
	{0.75,1},
	{0,0.25},
	{-0.25,1}
}

asteroid_large={
	init=function(self)
		self.ang=rnd(1)
		self.dir_ang=rnd(1)
		self.vang=0.01
		self.vel=rnd(0.5)+0.1
		self.col=7
		self.scale=8
		self.tag="asteroid"
		self.health=5
		self.vel=0
		self.points=10
	end,
	update=function(self)
		self.ang-=self.vang

		local sn,cs=sin(self.dir_ang),cos(self.dir_ang)
		self.posx+=cs*self.vel
		self.posy+=sn*self.vel

		if  self.posx<-20 or self.posx>140 or
			self.posy<-20 or self.posy>140 then
			destroy_entity(self)
		end
	end,
	draw=function(self)
		render(self,asteroid_large_1)
	end,
	on_destroy=function(self)
		for i=1,4 do
			create_entity(asteroid_small,self.posx,self.posy)
		end
	end
}

asteroid_small={
	init=function(self)
		self.ang=rnd(1)
		self.dir_ang=rnd(1)
		self.vang=0.01
		self.vel=rnd(0.5)+0.1
		self.col=7
		self.scale=3
		self.tag="asteroid"
		self.health=1
		self.vel=1
		self.points=5
	end,
	update=function(self)
		self.ang-=self.vang

		local sn,cs=sin(self.dir_ang),cos(self.dir_ang)
		self.posx+=cs*self.vel
		self.posy+=sn*self.vel

		if  self.posx<-20 or self.posx>140 or
			self.posy<-20 or self.posy>140 then
			destroy_entity(self)
		end
	end,
	draw=function(self)
		render(self,asteroid_large_1)
	end
}

ship_model={
	{-1,0},
	{1,1},
	{0.5,0},
	{1,-1}
}

ship={
	init=function(self)
		self.spr=1
		self.ang=0.5
		self.vang=0.01
		self.vel=1
		self.col=7
		self.scale=5
		self.health=5
	end,
	update=function(self)
		if(btn(0))self.ang+=self.vang
		if(btn(1))self.ang-=self.vang
		if btn(2) then
			local sn,cs=sin(self.ang),cos(self.ang)
			self.posx+=cs*self.vel
			self.posy+=sn*self.vel
		end
		
		if btnp(4) then
			local e=create_entity(
				bullet,
				self.posx,
				self.posy)
			e.ang=self.ang
		end
	end,
	draw=function(self)
		render(self,ship_model)
	end,
	on_collision=function(self,e)
		if(e.tag!="asteroid") return
		
		self.health-=1
		if (self.health<=0)run(stat(6))

		destroy_entity(e)
	end
}

function render(self,model)
	for i=0,#model-1 do
		local j=((i+1) % #model)
		local p1,p2=model[i+1],model[j+1]
		local s,c=sin(self.ang+0.5),cos(self.ang+0.5)

		local x1,y1=p1[1]*c-p1[2]*s,p1[2]*c+p1[1]*s
		local x2,y2=p2[1]*c-p2[2]*s,p2[2]*c+p2[1]*s

		line(
			x1*self.scale+self.posx,
			y1*self.scale+self.posy,
			x2*self.scale+self.posx,
			y2*self.scale+self.posy,self.col)
	end
end

function check_collision(a,b)
	local ba,bb={-1,-1,1,1},{-1,-1,1,1}

	local sa=a.scale or 1
	local sb=b.scale or 1
	
	for i=1,#ba do
		ba[i] *= sa
		bb[i] *= sb

		ba[i] += (i%2 == 0) and a.posy or a.posx
		bb[i] += (i%2 == 0) and b.posy or b.posx
	end

	rect(ba[1],ba[2],ba[3],ba[4],8)
	rect(bb[1],bb[2],bb[3],bb[4],8)

	return 
		ba[1]<bb[3] and 
		ba[3]>bb[1] and
		ba[2]<bb[4] and 
		ba[4]>bb[2]
end

function hit_entity(e,damage)
	e.health=e.health or 1
	e.health-=damage

	if e.health <= 0 then
		destroy_entity(e)
		return true
	end

	return false
end

entities={}
function create_entity(e,posx,posy)
	local ne={}
	
	ne.init=e.init
	ne.update=e.update
	ne.draw=e.draw
	ne.on_collision=e.on_collision
	ne.on_destroy=e.on_destroy
	
	ne.posx=posx
	ne.posy=posy

	ne.t=0
	
	add(entities,ne)
	ne.init(ne)
	
	return ne
end

function destroy_entity(e)
	if (e.on_destroy) e.on_destroy(e)
	del(entities,e)
	return e
end

score=0
function _init()
	create_entity(ship,64,64)
	create_entity(asteroid_controller,-128,-128)
end

function _update()
	for e in all(entities) do
		e.update(e)
		e.t+=1

		for t in all(entities) do
			if t!=e and check_collision(e,t) then
				if (e.on_collision) e.on_collision(e,t)
			end
		end
	end
end

function _draw()
	cls()
	
	for e in all(entities) do
		e.draw(e)
	end

	print("score: " .. score,50,4,7)
end
__gfx__
00000000000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700007007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000070000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000070000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700700000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000160501905019050000001b05019050190502005021050220502505027050000002e050000003305037050390503a0503b0503b0503b0502c0503c0503b05000000000003b0503d05000000
