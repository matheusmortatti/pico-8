pico-8 cartridge // http://www.pico-8.com
version 8
__lua__

objects = {}

-- colors!
c_black=0 c_dark_blue=1 c_dark_purple=2 c_dark_green=3  
c_brown=4 c_dark_gray=5 c_light_gray=6 c_white=7
c_red=8 c_orange=9 c_yellow=10 c_green=11       
c_blue=12 c_indigo=13 c_pink=14 c_peach=15

palette = {
	{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15},
	{0, 0, 0, 0, 2, 0, 0, 6, 2, 4,  4,  3,  5,  1,  4,  4},
	{0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0,  0}
}

scene_player = nil
pause_player = 0
pause_movement = 0

has_bullet = true
has_laser = true
has_djump = false

shake = 0

room = {x = 0, y = 0}

template = {
	init = function(this)

	end,

	update = function (this)

	end,

	draw = function(this)

	end
}

actor = {
	init = function(this)
		this.x_dir = 0
		this.y_dir = 0

		this.vx = 0
		this.vy = 0
		this.vxmax = 2
		this.vymax = 5
		this.airfric = 0.5
		this.grundfric = 2
		this.jumpheight = 7
		this.grav = 1

		this.on_ground = false
	end,

	update = function (this)

		-- movement --
		--------------

		this.on_ground = this.is_solid(0, 1)

		-- horizontal movement
		local accel = 2
		local fric = 0

		if this.on_ground then fric = this.grundfric
		else			       fric = this.airfric
		end

		if(this.x_dir~=0) then
			if (this.x_dir == 1 and this.vx < 0) or (this.x_dir == -1 and this.vx > 0) then
				this.vx = approach(this.vx, 0, fric)
			else
				this.vx = approach(this.vx, this.x_dir*this.vxmax, accel)
			end
		else
			this.vx = approach(this.vx, 0, fric)
		end
		

		-- gravity
		if this.on_ground then this.vy = 0
		else
			this.vy = approach(this.vy, this.vymax, this.grav)
		end
	end,

	draw = function(this)

	end
}

player = {
	init = function(this)
		this.pjump = false
		this.jump = false
		this.jump_count = 2
		this.jump_max = 2

		this.hp = 100
		this.invincible = false
		this.inv_timer = 0

		-- A buffer to store up to ib_size frames of inputs
		this.input_buffer = {}
		this.ib_size = 3
		for i=1,this.ib_size do add(this.input_buffer, false) end

		-- A buffer to store up to gb_size frames of when the player was grounded
		this.ground_buffer = {}
		this.gb_size = 3
		for i=1,this.gb_size do add(this.ground_buffer, false) end

		-- state:
		-- 0 = idle
		-- 1 = walking
		-- 2 = jumping
		-- 3 = morph ball
		this.state = 0

		this.equiped = bullet
		this.weapons = {bullet, laserbuilder}
		this.w_index = 1

		this.spr_timer = 0
		this.idle_spr = 8
		this.jump_spr = 1
		this.spr = 0
		this.flip_x = false
		this.flip_y = false

		this.hb = {x = 1, y = 1, w = 6, h = 7}

		this.facing = 1

		this.parent = actor
		this.parent.init(this)
		this.depth=10
	end,

	update = function (this)
		this.x_dir = btn(0) and -1 or btn(1) and 1 or 0
		this.y_dir = btn(2) and -1 or btn(3) and 1 or 0

		if pause_movement > 0 then
			this.x_dir = 0
			this.y_dir = 0
			pause_movement -= 1
		end	

		if this.invincible then
			this.inv_timer += 1
			if this.inv_timer > 30 then this.invincible = false this.inv_timer = 0 end
		end		

		this.facing = this.x_dir == 0 and this.facing or this.x_dir

		if btnp(4, 1) then
			this.w_index += 1
			this.w_index = this.w_index > #this.weapons and 1 or this.w_index
		end


		this.parent.update(this)

		-------------------------------
		-- Buffers
		------------------------------

		local has_jumped = false
		for i=1,this.ib_size do 
			has_jumped = has_jumped or this.input_buffer[i]
		end

		local jump = btnp(4) and not this.pjump and this.jump_count > 0
		this.pjump = btnp(4)

		for i=2,this.ib_size do
			this.input_buffer[i-1] = this.input_buffer[i]
		end
		this.input_buffer[this.ib_size] = btnp(4)

		local grounded = false
		for i=1,this.gb_size do
			grounded = grounded or this.ground_buffer[i]
		end

		for i=2,this.gb_size do
			this.ground_buffer[i-1] = this.ground_buffer[i]
		end
		this.ground_buffer[this.gb_size] = this.on_ground

		-------------------------------
		-- movement
		------------------------------
		this.jump_max = has_djump and 2 or 1

		if ((jump or has_jumped) and this.on_ground) or 
		   (jump and not this.on_ground and grounded) or
		   (jump and this.jump_count > 0) then
			this.vy = -this.jumpheight 
			this.jump = true
		elseif this.on_ground then
			this.jump_count = this.jump_max
			this.jump = false
		elseif not this.on_ground and this.jump_count == this.jump_max then
			this.jump_count -= 1
		end

		if jump then this.jump_count -=1 end

		move_x(this)
		move_y(this)

		-------------------------------
		-- attack
		-------------------------------

		if this.weapons[this.w_index] == bullet and btnp(5) then
			local b = create_object(this.x+4, 
				  				  	this.y+4, 
				  				  	bullet)
			add(b.ignore, player)
			if this.x_dir ~= 0 or this.y_dir ~= 0 then	
				b.vx = 10*this.x_dir
				b.vy = 10*this.y_dir
			else
				b.vx = 10*this.facing
			end

		elseif this.weapons[this.w_index] == laserbuilder and btn(5) then
			local l = create_object(this.x, 
				  				  	this.y, 
				  				  	laserbuilder)
			add(l.ignore, player)
			if this.x_dir ~= 0 or this.y_dir ~= 0 then	
				l.dir.x = this.x_dir
				l.dir.y = this.y_dir
			else
				l.dir.x = this.facing
			end
		end


		-------------------------------
		-- states
		-------------------------------

		if this.state == 0 then 		-- idle
			if this.jump then 
				this.state = 2
			elseif this.x_dir ~= 0 and this.on_ground then 
				this.state = 1
				this.spr_timer = 0
			-- elseif morph ball then ...
			end
		elseif this.state == 1 then 	-- walking
			if this.jump then
				this.state = 2
			elseif this.x_dir == 0 then
				this.state = 0

			-- elseif morph ball then ...
			end
		elseif this.state == 2 then 	-- jumping
			if not this.jump then 
				if this.x_dir == 0 then 
					this.state = 0
				else
					this.state = 1
					this.spr_timer = 0
				end
			end
		elseif this.state == 3 then 	-- morph ball

		end


		-------------------------------
		-- animation
		-------------------------------
		
		if this.state ~= 2 then
			this.spr_timer+=0.3
			if this.state == 0 then
				this.spr = this.idle_spr
			else
				this.spr = this.idle_spr + this.spr_timer % 3
			end
		else
			this.spr_timer += 1
			this.spr = this.jump_spr + this.spr_timer % 4
		end

		if this.x_dir == -1 then this.flip_x = true
		elseif this.x_dir == 1 then this.flip_x = false
		end
	end,

	draw = function(this)
		--print("x: " .. this.x .." y: " .. this.y .. " vx: " .. this.vx + this.x_frac, 0, 0, c_red)
		--print(this.hp, 0, 16, c_red)
		--rectfill(this.x + this.hb.x, this.y + this.hb.y, this.x + this.hb.x + this.hb.w-1, this.y + this.hb.y + this.hb.h-1, c_pink)
		if this.inv_timer % 4 < 2 then
			spr(this.spr, this.x, this.y, 1, 1, this.flip_x, this.flip_y)
		end
	end,

	dmg_react = function(this, inflict)
		local x, y = normalize(this.x+this.hb.x+this.hb.w/2-(inflict.x+inflict.hb.x+inflict.hb.w/2), 
							   this.y+this.hb.y+this.hb.h/2-(inflict.y+inflict.hb.y+inflict.hb.h/2))
		--x, y = -x,-y

		this.vx, this.vy = x*5, y*5
		this.invincible = true

		pause_movement = 5
	end
}

tortuga = {
	init = function(this)
		-- 0 = protected
		-- 1 = shooting
		this.state = 0
		this.hp = 2
		this.invincible = true

		this.cs_timer = 0
		this.shoot_timer = 0

		this.dbox = create_object(this.x, this.y, dmg_box)
		this.dbox.hb.w, this.dbox.hb.h = 7, 4
		this.dbox.hb.x = 1
		this.dbox_off = {x = 0, y = 3}
		
		add(this.dbox.ignore, walker)
		add(this.dbox.ignore, tortuga)
		add(this.dbox.ignore, flyer)
	end,

	update = function (this)
		this.cs_timer += 1

		if this.hp <= 0 then
			del(objects, this)
			del(objects, this.dbox)
			for i=1,10 do
				create_object(this.x+4, this.y+4, death_particle)
			end
		end

		local dist_x = scene_player ~= nil and (scene_player.x-this.x) or 1000
		local dist_y = scene_player ~= nil and (scene_player.y-this.y) or 1000

		if abs(dist_x) < 50 and abs(dist_y) < 16 then
			this.cs_timer += 1

			if this.state == 0 and this.cs_timer > 60 then
				this.cs_timer = 0
				this.state = 1
			elseif this.state == 1 and this.cs_timer > 100 then
				this.cs_timer = 0
				this.state = 0
			end
		else
			this.state = 0
		end

		if this.state == 1 then
			this.invincible = false
			this.shoot_timer += 1
			if this.shoot_timer > 25 then
				local b = create_object(this.x+4, 
				  				  		this.y+4, 
				  				  		bullet)
				b.vx = sign(dist_x)*5
				add(b.ignore,this.type)
				this.shoot_timer = 0
			end
			this.dbox_off.y = 0
		elseif this.state == 0 then 
			this.invincible = true
			this.dbox_off.y = 3
		end

		this.dbox.x, this.dbox.y = this.x + this.dbox_off.x, this.y + this.dbox_off.y
	end,

	draw = function(this)
		local s = this.state == 0 and 18 or 19
		spr(s, this.x, this.y)
	end
}

dripper = {
	init = function(this)
		this.timer = 0
		this.b_timer = 0
		this.state = 0
	end,

	update = function (this)
		this.timer += 1
		if this.timer > 60 then
			this.state = this.state == 0 and 1 or 0
			this.timer = 0
		end

		if this.state == 1 then
			this.b_timer += 1

			if this.b_timer > 5 then
				local b = create_object(this.x+4, 
					  				  	this.y+4, 
					  				  	bullet)
				b.vy = 5
				add(b.ignore,this.type)
				--add(b.dbox.ignore, this.type)
				this.b_timer = 0
			end
		end
	end,

	draw = function(this)
		spr(23, this.x, this.y)
	end
}

flyer = {
	init = function(this)
		this.spr = 20
		this.spr_timer = 0

		this.hp = 2

		this.fric = 0.5

		-- 0 = stopped
		-- 1 = following
		this.state = 0

		this.base_y = this.y
		this.sin_timer = 0

		this.spd = 0.5

		this.dbox = create_object(this.x, this.y, dmg_box)
		this.dbox.hb.w, this.dbox.hb.h = 7, 3
		this.dbox.hb.x = 1
		this.dbox_off = {x = 0, y = 3}

		add(this.dbox.ignore, walker)
		add(this.dbox.ignore, tortuga)
		add(this.dbox.ignore, flyer)
	end,

	update = function (this)

		local dist = scene_player == nil and 1000 or 
					 sqrt((scene_player.x-this.x)*(scene_player.x-this.x) + 
					 	  (scene_player.y-this.y)*(scene_player.y-this.y))

		if dist < 40 then 
			this.state = 1 
		end

		if this.hp <= 0 then
			del(objects, this)
			del(objects, this.dbox)

			for i=1,10 do
				create_object(this.x+4, this.y+4, death_particle)
			end
		end
		

		if this.state == 0 then
			this.spr = 22
			this.dbox_off.y = 1
		elseif this.state == 1 then
			this.dbox_off.y = 3
			this.sin_timer += 0.05

			this.y = this.base_y + 2*cos(this.sin_timer+0.5)

			-- move actor here
			-- ...
			if scene_player ~= nil then
				local dir_x = scene_player.x - this.x
				local dir_y = scene_player.y - this.y
				local len   = length(dir_x, dir_y)
				local c 	= len == 0 and 0 or dir_x / len
				local s 	= len == 0 and 0 or dir_y / len

				-- move actor
				this.x += c*this.spd + this.vx
				this.y += s*this.spd + this.vy

				this.vx = approach(this.vx, 0, this.fric)
				this.vy = approach(this.vy, 0, this.fric)
			end

			this.base_y = this.y - 2*cos(this.sin_timer+0.5)
			

			-- handle animation
			this.spr_timer += 0.1
			this.spr = 20 + this.spr_timer % 2
		end

		this.dbox.x, this.dbox.y = this.x + this.dbox_off.x, this.y + this.dbox_off.y
	end,

	draw = function(this)
		spr(this.spr, this.x, this.y)
	end,

	dmg_react = function(this, inflict)
		if inflict.type ~= bullet then return end
		local x, y = normalize(this.x+this.hb.x+this.hb.w/2-(inflict.x+inflict.hb.x+inflict.hb.w/2), 
							   this.y+this.hb.y+this.hb.h/2-(inflict.y+inflict.hb.y+inflict.hb.h/2))
		--x, y = -x,-y

		this.vx, this.vy = x*3, y*3

		pause_movement = 5
	end
}

walker = {
	init = function(this)
		this.parent = actor
		this.parent.init(this)

		this.rot = 0.25
		this.dir = 0.5

		this.hp = 2

		this.dbox = create_object(this.x, this.y, dmg_box)
		this.dbox_off = {x = 0, y = 0}
		add(this.dbox.ignore, walker)
		add(this.dbox.ignore, tortuga)
		add(this.dbox.ignore, flyer)
	end,

	update = function (this)

		if this.hp <= 0 then
			del(objects, this)
			del(objects, this.dbox)
			for i=1,10 do
				create_object(this.x+4, this.y+4, death_particle)
			end
		end

		local x_dir = btn(0) and -1 or btn(1) and 1 or 0
		local y_dir = btn(2) and -1 or btn(3) and 1 or 0

		-- locate edge or wall
		if this.is_solid(cos(this.dir), sin(this.dir)) then
			this.dir -= this.rot
			if this.dir == -0.25 then this.dir = 0.75 end
		elseif not this.is_solid(cos(this.dir+this.rot), sin(this.dir+this.rot)) then
			this.dir += this.rot
			this.x += 4*cos(this.dir)
			this.y += 4*sin(this.dir)
			while not this.is_solid(cos(this.dir+this.rot), sin(this.dir+this.rot)) do
				this.x += cos(this.dir+this.rot)
				this.y += sin(this.dir+this.rot)
			end
		else

		end

		this.dir = frac(this.dir)

		this.vx = cos(this.dir) * 0.5
		this.vy = sin(this.dir) * 0.5

		move_x(this)
		move_y(this)

		this.dbox.x, this.dbox.y = this.x + this.dbox_off.x, this.y + this.dbox_off.y
	end,

	draw = function(this)
		--rectfill(this.x + this.hb.x, this.y + this.hb.y, this.x + this.hb.x + this.hb.w-1, this.y + this.hb.y + this.hb.h-1, c_blue)
		local offset = (this.dir == 0.25 or this.dir == 0.75) and 1 or 0
		spr(16 + offset,
			this.x, this.y, 1, 1,
			(this.dir == 0 or this.dir == 0.25) and true or false,
			(this.dir == 0 or this.dir == 0.25) and true or false)
	end
}

fadeout = {
	init = function(this)
		this.time=0
		this.delay=30
		this.index=1
	end,

	update = function (this)
		this.time+=1
		if this.time > this.delay then
			this.index+=1
			if this.index > #palette then
				del(objects, this)
				create_object(0, 0, fadein)
			end
			this.time=0
		end
	end,

	draw = function(this)
		for i=1, 16 do
			pal(i-1, palette[this.index][i])
		end
	end
}

fadein = {
	init = function(this)
		this.time 		= 0
		this.delay 		= 30
		this.index 		= #palette
	end,

	update = function (this)
		this.time+=1
		if this.time > this.delay then
			this.index-=1
			if this.index < 1 then
				del(objects, this)
			end
			this.time=0
		end
	end,

	draw = function(this)
		print("here", 0, 24, c_red)
		for i=1, 16 do
			pal(i-1, palette[this.index][i])
		end
	end
}

laserbuilder = {
	init = function(this)
		this.dir = {x=1,y=0}
	end,

	update = function (this)
		local start = (this.dir.x < 0 or this.dir.y < 0) and 0 or 1
		for i=start,3+start do

			local l = create_object(8*((this.x+this.dir.x*(i*8))/8),
									8*((this.y+this.dir.y*(i*8))/8),
									laser)
			l.dir.x=this.dir.x
			l.dir.y=this.dir.y

			if solid_at(this.x+this.dir.x*(i*8), this.y+this.dir.y*(i*8), sgn(this.dir.x)*8, sgn(this.dir.y)*8) then break end
		end

		del(objects, this)
	end,

	draw = function(this)

	end
}

laser = {
	init = function(this)
		this.dir = {x=1,y=0}
		this.drawn = false
		this.dmg=0.1

		add(this.ignore, player)
		add(this.ignore, laser)
		add(this.ignore, laserbuilder)
		add(this.ignore, dmg_box)
		add(this.ignore, death_particle)
	end,

	update = function (this)
		local dxsign, dysign = sgn(this.dir.x),sgn(this.dir.y)
		this.hb= {x=dxsign*2*(1-abs(this.dir.x)), 
				  y=dysign*2*(1-abs(this.dir.y)),
				  w=dxsign*(4+4*abs(this.dir.x)),
				  h=dysign*(4+4*abs(this.dir.y))}

		while this.is_solid(0, 0) do
			this.hb.w = approach(this.hb.w, 0, this.dir.x)
			this.hb.h = approach(this.hb.h, 0, this.dir.y)
		end

		local cw,ch=false, false
		if this.hb.w < 0 then
			cw=true
			this.hb.w,this.x=abs(this.hb.w),this.x+this.hb.w
		end
		if this.hb.h < 0 then
			ch=true
			this.hb.h,this.y=abs(this.hb.h),this.y+this.hb.h
		end

		local enemy = this.place_meeting(this.x, this.y)
		take_damage(enemy, this)
		enemy = enemy == nil and "none" or enemy.str

		if this.hb.w < 0 and cw then
			this.hb.w,this.x=-this.hb.w,this.x+this.hb.w
		end
		if this.hb.h < 0 and ch then
			this.hb.h,this.y=-this.hb.h,this.y+this.hb.h
		end

		if this.drawn then del(objects, this) end
	end,

	draw = function(this)
		this.drawn=true
		
		for i=1,3 do
			local size_x,size_y=rnd(2)+1,rnd(2)+1
			local pos_x,pos_y=this.x+this.hb.x+sign(this.hb.w)*rnd(abs(this.hb.w)-size_x),this.y+this.hb.y+sign(this.hb.h)*rnd(abs(this.hb.h)-size_y)
			rectfill(pos_x, pos_y, pos_x+size_x, pos_y+size_y, c_light_gray)
			rect(pos_x, pos_y, pos_x+size_x, pos_y+size_y, c_white)
			--rectfill(this.x+this.hb.x,this.y+this.hb.y,this.x+this.hb.x+this.hb.w, this.y+this.hb.y+this.hb.h, c_red)
		end
	end
}

bullet = {
	init=function(this)
		this.hb 		= {x = -2, y = -2, w = 4, h = 4}

		this.radius 	= 2
		this.col 		= c_white

		this.timer = 0

		add(this.ignore, dmg_box)
		add(this.ignore, bullet)
		add(this.ignore, smoke_part)
		add(this.ignore, fire_part)
		add(this.ignore, explosion)
		add(this.ignore, laser)
		add(this.ignore, laserbuilder)
		add(this.ignore, death_particle)
	end,

	update=function(this)
		this.timer+=1

		local col_x, col_y
		local enemy_x, enemy_y
		col_x, enemy_x = move_x(this, true) 
		col_y, enemy_y = move_y(this, true)
		if col_x or col_y then
			create_object(this.x, this.y, explosion)
			del(objects, this)

			take_damage(enemy_x or enemy_y, this)
		end

		if this.timer > 120 then
			del(objects, this)
			del(objects, this.dbox)
		end
	end,

	draw=function(this)
		circfill(this.x, this.y, this.radius, this.col)
	end
}

fire_part = {
	init = function(this)
		this.vx 		= rnd(1) - 0.5
		this.vy 		= -rnd(0.5) - 0.3
		this.radius 	= rnd(2)+1
		this.spd 		= rnd(0.5) + 1
		this.time 		= 0

		if rnd(1) < 0.5 then
			this.col = c_white
		else
			this.col = c_light_gray
		end
	end,

	update = function (this)
		this.x += this.vx
		this.y += this.vy
		this.vx = approach(this.vx, 0, 0.1)

		this.time+=1
		if this.time > 5 then this.radius-=this.spd this.time=0 end

		if this.radius < 0 then del(objects, this) end
		if this.radius < 0.5 then this.col = c_light_gray end
	end,

	draw = function(this)
		circfill(this.x, this.y, this.radius, this.col)
	end
}

explosion = {
	init = function(this)
		this.radius 	= rnd(3) + 3
		this.solid 		= false
		this.step 		= 1

		for i=1,1*this.radius do
			if i%2==0 then
				--create_object(this.x + rnd(1*this.radius)-0.5*this.radius, this.y + rnd(1*this.radius)-0.5*this.radius, smoke_part)
			end
			create_object(this.x + rnd(1*this.radius)-0.5*this.radius, this.y + rnd(1*this.radius)-0.5*this.radius, fire_part)
		end

		
	end,

	update = function(this)
		this.step += 0.5
		this.x += rnd(2)-1
		this.y += rnd(2)-1
		this.radius -= rnd(1)
		if this.step > 3 then del(objects, this) end
	end,

	draw = function(this)
		if this.step<2 then circfill(this.x, this.y, this.radius, c_white)
		else				circfill(this.x, this.y, this.radius, c_light_gray)
		end
	end
}

dmg_box = {
	init = function(this)
		this.dmg 		= 1  -- standard damage
		this.ignore 	= {} -- doesn't ignore anyone
		this.destroy 	= false
	end,

	update = function (this)
		local enemy = this.place_meeting(this.x, this.y, nil, this.ignore)
		take_damage(enemy, this)
		if this.destroy then del(objects, this) end
	end,

	draw = function(this)
		--rectfill(this.x + this.hb.x, this.y + this.hb.y, this.x + this.hb.x + this.hb.w-1, this.y + this.hb.y + this.hb.h-1, c_red)
	end
}

camera_obj = {
	init = function(this)
		this.target_x = 0--this.x
		this.target_y = 0--this.y

		this.spawned = false

		this.spd = 7
	end,

	update = function(this)
		if scene_player ~= nil then
			this.target_x = flr(scene_player.x/128)*128
			this.target_y = flr(scene_player.y/128)*128
		end

		this.x = approach(this.x, this.target_x, this.spd)
		this.y = approach(this.y, this.target_y, this.spd)

		if this.x == this.target_x and this.y == this.target_y and not this.spawned then
			spawn_room(this.x/128, this.y/128)
			this.spawned = true
		elseif this.x ~= this.target_x or this.y ~= this.target_y then
			this.spawned = false
		end
	end,

	draw = function(this)
		if shake >= 0 then
			camera(this.x+rnd(2)-1, this.y+rnd(2)-1)
			shake-=1
		else
			camera(this.x, this.y)
		end
		
	end
}

death_particle = {
	init = function(this)
		this.hb = {x=0, y=0, w=1, h=1}

		if rnd(1) > 0.5 then
			this.col = c_white
		else 
			this.col = c_light_gray
		end

		this.parent = actor
		this.parent.init(this)

		this.vx = sign(rnd(2)-1)*(rnd(2)+2)
		this.jumpheight = (rnd(5)+4)
		this.vy = -this.jumpheight

		this.airfric = 0.2
		this.groundfric = 0.2

		this.bounce = 2

	end,

	update = function (this)

		this.parent.update(this)

		if this.on_ground then
			this.vy = -this.jumpheight/this.bounce
			this.bounce*=2
		end

		move_x(this, false)
		move_y(this, false)

		if this.bounce < 0.2 then del(objects, this) end
	end,

	draw = function(this)
		pset(this.x, this.y, this.col)
	end
}

function take_damage(take, inflict)
	if take == nil or inflict == nil or
	   (take.invincible~=nil and take.invincible)  then return end

	if take.hp ~= nil then
		if inflict.dmg then take.hp -= inflict.dmg
		else take.hp -= 1 end

		if take.type.dmg_react ~= nil then 
			take.type.dmg_react(take, inflict) 
		end
	end
end

function move_x(obj, col_obj)
	if sign(obj.x_frac) ~= sign(obj.vx) then obj.x_frac = 0 end
	local newvx = obj.vx + obj.x_frac
	obj.x_frac += frac(obj.vx)
	obj.x_frac = frac(obj.x_frac)

	for i = 1, abs(newvx), 1 do
		if obj.is_solid(sign(newvx), 0) then
			obj.vx = 0
			obj.x_frac = 0
			return true, nil
		end

		
		if col_obj then
			local e = obj.place_meeting(obj.x+sign(newvx), obj.y)
			if e then
				obj.vx = 0
				obj.x_frac = 0
				return true, e
			end
		end

		obj.x += sign(newvx)
	end

	return false, nil
end

function move_y(obj, col_obj)
	if sign(obj.y_frac) ~= sign(obj.vy) then obj.y_frac = 0 end
	local newvy = obj.vy + obj.y_frac
	obj.y_frac += frac(obj.vy)
	obj.y_frac = frac(obj.y_frac)

	for i = 1, abs(newvy), 1 do
		if(obj.is_solid(0, sign(newvy))) then
			obj.vy = 0
			obj.y_frac = 0
			return true, nil
		end

		if col_obj then
			local e = obj.place_meeting(obj.x, obj.y+sign(newvy))
			if e then 
				obj.vy = 0
				obj.y_frac = 0
				return true, e
			end
		end

		obj.y += sign(newvy)
	end

	return false, nil
end

	
function create_object(x, y, type)
	local obj = {}

	obj.type = type
	obj.x = x
	obj.y = y
	obj.vx = 0
	obj.vy = 0
	obj.depth = 1
	obj.hb = {x = 0, y = 0, w = 8, h = 8}	-- hitbox
	obj.solid = true;
	obj.ignore = {}
	obj.x_frac = 0
	obj.y_frac = 0

	obj.is_solid = function(ox, oy)
		return 	--obj.place_meeting(obj.x + ox, obj.y + oy, nil, obj.ignore) or
				solid_at(obj.x + obj.hb.x + ox, obj.y + obj.hb.y + oy, obj.hb.w, obj.hb.h)
	end

	-- object collision
	obj.place_meeting=function(x, y, type)
		local px = obj.x
		local py = obj.y

		obj.x = x
		obj.y = y

		-- check for object collision
		local other = nil
	 	for i = 1, #objects do
			other = objects[i]

			--local collide = is_any(t, other.type)

			if not is_any(obj.ignore, other.type) then

				-- check hitbox collision
				if(other ~= obj and ((type ~= nil and type == other.type) or (type == nil and other.solid)) and
				   obj.x + obj.hb.x 	< other.x + other.hb.x + other.hb.w and
				   other.x + other.hb.x < obj.x + obj.hb.x + obj.hb.w 		and
				   obj.y + obj.hb.y		< other.y + other.hb.y + other.hb.h and
				   other.y + other.hb.y < obj.y + obj.hb.y + obj.hb.h) then
					
					obj.x = px
					obj.y = py

					return other
				end
			end
		end

		obj.x = px
		obj.y = py
		return nil
	end

	obj.type.init(obj)
	add(objects, obj)
	return obj
end

function spawn_room(mx, my)

	del_all_but(objects, {player, camera_obj})

	for i=0,15 do
		for j=0,15 do
			local spr = mget(mx*16+i, my*16+j)

			if spr == 16 then
				create_object(mx*128+i*8, my*128+j*8, walker)
			elseif spr == 18 then
				create_object(mx*128+i*8, my*128+j*8, tortuga)
			elseif spr == 23 then
				create_object(mx*128+i*8, my*128+j*8, dripper)
			elseif spr == 22 then
				create_object(mx*128+i*8, my*128+j*8, flyer)
			end
		end
	end
end

----------------------
-- helper functions --
----------------------

function del_all_but(list, save)
	for o in all(list) do
		if not is_any(save, o.type) then
			del(list, o)
		end
	end
end

function frac(v)
	return v-floor(v)
end

function floor(v)
	return v - sign(v)*((sign(v)*v)%1)
end

function length(x, y)
	return sqrt(x*x + y*y)
end

function normalize(x, y)
	local l = length(x, y)
	if l ~= 0 then return x/l,y/l end
	return x, y
end

function is_any(list, obj)
	for o in all(list) do
		if o == obj then return true end
	end
	return false
end

function rnd_range(a, b)
	return rnd(b-a)+a
end

function abs(val)
	return val < 0 and -val or val
end

function sign(val)
	return (val < 0 and -1) or (val > 0 and 1) or 0
end

function clamp(val, a, b)
	return min(max(val, a), b)
end

function approach(val, target, step)
	return val > target and max(val - abs(step), target) or min(val + abs(step), target)
end

function solid_at(x, y, w, h)
	return tile_flag_at(x, y, w, h, 1)
end

function enemy_at(x, y)
	return tile_flag_at(x, y, 1, 1, 2)
end

function tile_flag_at(x, y, w, h, flag)
	if w==0 or h==0 then return false end
	for i=flr(x/8), flr((x+w-1)/8),sgn(w) do
		for j=flr(y/8), flr((y+h-1)/8),sgn(h) do
			if(fget(tile_at(i, j), flag)) then
				return true
			end
		end
	end

	return false
end

function tile_at(cel_x, cel_y)
	return mget(cel_x, cel_y)
end

----------------------
-- pico 8 functions --
----------------------

function _init()
	scene_player = create_object(8, 8, player)
	scene_camera = create_object(0, 0, camera_obj)
	spawn_room(0, 0)
end

function _update()
	foreach(objects, function(obj)
					 	obj.type.update(obj)
					 end)
end

function _draw()
	cls()
	map(0, 0, 0, 0, 128, 64, 1)

	foreach(objects, function(obj)
					 	obj.type.draw(obj)
					 end)
end


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000066660000000000000000000000000000000000000000000000000
00000000000000000007700000077000000770000066660000000000000666600006666000677770000666600000000000000000000000000000000000000000
00000000007007000077770000777700007777000077776000066660006776600067777000777660006777700000000000000000000000000000000000000000
00000000077077700777000007777770000777700000667000677770007666600077766000766660007776600000000000000000000000000000000000000000
00000000077777700777700007770770000077700000007000777660007777700076666000777770007666600000000000000000000000000000000000000000
00000000007777000077770000700700007777000077777000766660007777700077777000666600007777700000000000000000000000000000000000000000
00000000000770000007700000000000000770000066667000777770006666000066660007000070076666000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000700000700700007007000070070000000000000007000000000000000000000000000000000000000000
00000000000077600000000000700070000000000000000000070700606666060000000000000000000000000000000000000000000000000000000000000000
00700070077700060000000000777770007000700000000000076700000770000000000000000000000000000000000000000000000000000000000000000000
00770770007700060000000007777777070060070000600000770770006776000000000000000000000000000000000000000000000000000000000000000000
00777770000700060070007007006007077606770076067000006000006776000000000000000000000000000000000000000000000000000000000000000000
07000007007700060077777006060606070060070770607700000000006776000000000000000000000000000000000000000000000000000000000000000000
70700007077707060777777706606066000000000070007000000000006776000000000000000000000000000000000000000000000000000000000000000000
60000006000070060766066700666660000000000000000000000000006776000000000000000000000000000000000000000000000000000000000000000000
06666660000007600066666000600060000000000000000000000000000770000000000000000000000000000000000000000000000000000000000000000000
07707077077077700770077007777770666660006666600066660000000000000000000000000000000000000000000000000000000000000000000000000000
77606607776000777660007766666667000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76000000760076076600706766666667666666006666660066660000000000000000000000000000000000000000000000000000000000000000000000000000
00007606000766060007600666666667666666006666660066660000000000000000000000000000000000000000000000000000000000000000000000000000
60076600600660000076600066666667777766007777660077770000000000000000000000000000000000000000000000000000000000000000000000000000
66006006670000667006600660666667666666606666660066660000000000000000000000000000000000000000000000000000000000000000000000000000
66600066667006666600006666066667777766607777000077770000000000000000000000000000000000000000000000000000000000000000000000000000
06660666066606606660066006666660777777707777000077770000000000000000000000000000000000000000000000000000000000000000000000000000
60606677000670000006700077777777777777707777000077770000000000000000000000000000000000000000000000000000000000000000000000000000
06066770000670000006700006666660777766607777000077770000000000000000000000000000000000000000000000000000000000000000000000000000
00607700000670000006700000077000666666606666660066660000000000000000000000000000000000000000000000000000000000000000000000000000
00067000000670000006700000700700777766007777660077770000000000000000000000000000000000000000000000000000000000000000000000000000
00067000000670000006700000700700666666006666660066660000000000000000000000000000000000000000000000000000000000000000000000000000
00067000000670000060770000077000666666006666660066660000000000000000000000000000000000000000000000000000000000000000000000000000
00067000000670000606677006666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00067000000670006060667777777777666660006666600066660000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000040000000000000000000000000004000400000004040000000000000000030303030000000000000000000000000101010300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2020202020202020202020202020202020202020202020202020202020202020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002020000000000017000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000010000000000000002020000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000002333333333230000002020000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000002000000000200000002020000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000002333333333230000002020000000000000000000000000002220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000016000000002020000000000000000000000012222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002020000000000000000000000022222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2033330000000000000000000033332020000010000000000000000000160020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000172020333333230000000023000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002020000000300000000030000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000012000000000000000000002020000000310000000032000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000002333333323002333332300000000000000310000002333333333333320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000003000000030003000003000000000000000310000003000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000003200000032003200003200000000000000320000003200000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2221202122202122202120222122222020202020202020202020202020202020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

