drv = driver()
'[
	README
	Collix delivers basic AABB collisions forevery sprite on the whole map it.
	Please take the 10 minutes to read this Readme, it'll make using this engine MUCH easier :)
	
	0.) Setup Collix
		Map-Size: x mod 16 = 0 and y mod 16 = 0
		Map-Tiles: 8x8
		
	
	1.) Your map has to follow these rules on it's logic layer
		Tile Indexes and where they block collision [t][r][b][l]:
		
			0 - [t][r][b][l]
			1 - [x][x][x][x]
			2 - [x][r][x][l]
			3 - [x][r][x][x]
			4 - [x][x][x][l]
			5 - [t][x][x][x]
			6 - [x][x][b][x]
			7 - halfblock [-]
			8 - topline ['']
			9 - bottomline [_]
			10 - special property block 1 (ice, lava, slimey, bouncy, speedup...whatever you want it to be!)
			11 - special property block 2
			12 - special property block 3
			
	
	2.) The actor-Class
		Your Characters, Enemies and Fireballs need a few things...
		First of all every entity on the screen need to be created with classes
		Those classes need to inherit from the 'actor' class. It stands for Dynamic-Object.
		How? Here's how: class yourAmazingClass(actor) endclass
		This class contains the follow variables and functions:
		
			-------------------------------------------------------------
			What					Var-Name				Default		
			-------------------------------------------------------------
			identifier:				id = num				nil
			position: 				p = vec2 				(0,0)
			velocity: 				v = vec2 				(0,0)
			CollisionBox
				'-	top-left:	 	cBox_tl = vec2 			(0,0)
				'-	bot-right:	 	cBox_br = vec2 			(0,0)
			
			physics:				hasPhysics = bool 		true			TODO
			turn off collision 		isGhost = bool	 		false			TODO
			mass:					mass = num 				100				TODO
			bouncyness:				bouncy = num	 		0				TODO
			
			collTags				list					empty
			
			-------------------------------------------------------------
			Function-Name					Effect						
			-------------------------------------------------------------
			init(actor_objects, ...)		Call this once after creating
				'- actor_objects			
				'- actor_objects
				'- actor_objects
				'- actor_objects
				'- actor_objects
				'- actor_objects
			-------------------------------------------------------------
			
			
	2.1) Furthermore Collix introduces a few global variables it needs to function
			
			-------------------------------------------------------------
			Var-Name			Type					Purpose			
			-------------------------------------------------------------
			collixEngine		collix					Instance of collix			
			actor_objects		dict(id, actor)			holds all			
			-------------------------------------------------------------
			
			
	3.) Collix returns a list that you can use in your object update function
		collisions = list => Includes every object that has been collided with (so you can check if the player takes damage for example...)
		
	4.) What Collix can not handle
		Rotation. Your Collision box has to be axis aligned (Google: "AABB collision")
		More than 25 active actors
		
	5.) Drawbacks
		Collix checks the whole map, every frame. Too many sprites on a too big map may be a problem
			TODO: Add clipping
		
		The dev:
			He aint no genius. He aint no mathemagician. He just wants easy to use and simple yet perfomant physics and collision
	
	6.) Dev Notes
		I've never ever written an "engine" or anything like this before.
		There will probably be a lot of things that can be done much better.
		I was just frustrated that I couldnt just make a jump and run easily due to the lack of a collision-function
		Since i had a basic physics function done already, i thought i make this a small "Engine" that handles both
		The goal is to make this engine easy to use
		
		TODO: Optimization.
			Using Bytes/Bits to save memory where it makes sense
	
']


'----REMOVE ME LATER----
rMap = load_resource("rm.map")
cps = list()

'---- MAIN CLASSES ----

class collix_mapTile
	var id = 0
	var p = vec2(0,0)
	var isGhost = true
	var bb_o = vec2(0,0)
	var bb_wh = vec2(0,0)
	var passthrough = list() 't,r,b,l => boolean
	
	def init(idv, ghostv, bb_ov, bb_whv, pth)
		id = idv
		isGhost = ghostv
		bb_o = bb_ov
		bb_wh = bb_whv
		passthrough = pth
	enddef
	
	def noFunc()
	enddef
endclass

class collix_engine
	'---- VAR ----
	var isReady = false
	
	var maxspd_x = 7 'General Maximum Speed
	var maxspd_y = 7 'General Maximum Speed
	
	var gravity = 0.2
	var friction = 0.80
	
	var actors = nil 'The active_objects dict goes here in init()
	var newActors = nil
	var toBeRemoved = list()
	
	var amap = nil;
	var mapTiles = dict()
	
	var gridsize = vec2(0,0)
	var gridRes = 16 'map gets divided by this for broad collision phase
	var grid = list() '= list(0...x) => where each x = list(0...y) => where each y = dict(objects...) => in short x(y(o))
	var gridTiles_x = dict()
	var gridTiles_y = dict()
	
	'---- FUNCTIONS ----
	def setup(res, maxspd_x, maxspd_y, gravity, friction)
	'todo
	enddef

	def init(m, x, y, actorDict)
		if isReady = flase then
			amap = m
			init_mapTiles()
			print "[Collix] >> Setting Map Tile Properties";
			init_grid(m, x, y)
			print "[Collix] >> Setting Grid with x:" + str(x) +" | y:" + str(y);
			init_actors(actorDict)
			print "[Collix] >> Setting Actors";
			isReady = true;
		endif
	enddef
	
	def run(time)
		setGridState()
		
		for a in actors
			anActor = actors(a)
			
			'Check velocity limit and reduce if over limit
			unpack(anActor.v, ovx, ovy)
			if abs(ovx) > anActor.ms_x then
				ovx = anActor.ms_x * sgn(ovx)
			endif
			if abs(ovy) > anActor.ms_y then
				ovy = anActor.ms_y * sgn(ovy)
			endif
			anActor.v = vec2(ovx, ovy)
			
			unpack(anActor.p, opx, opy)
			a_op = vec2(opx, opy) 'save old position
			
			anActor.p = vec2(opx, round(opy+ovy)) 'only move along y axis first
			
			'CHECK Y-AXIS MOVED ACTOR
			rrmax = 1
			rerun = true
			rrcount = 0
			while rerun = true
				rerun = false
				actors_tc = dict()
				tiles_tc = dict()
				
				scan_map(anActor, actors_tc, tiles_tc) 'find possible collisions
				for ti in tiles_tc
					tid = tiles_tc(ti)
					if tid > 0 then
						cr_tile(anActor, a_op, mapTiles(tid), ti)
						'push(cps,ti); 'REMOVE ME LATER
						rerun = true;
						rrcount = rrcount + 1
						'exit
					endif
				next
				if rrcount > rrmax then
					rerun = false
				endif
			wend
			
			'CHECK FULLY MOVED ACTOR
			unpack (anActor.p, apx, apy)
			anActor.p = vec2(round(apx+ovx), apy) 'move along x and y now
			rerun = true
			rrcount = 0
			while rerun = true
				rerun = false
				actors_tc = dict()
				tiles_tc = dict()
				
				scan_map(anActor, actors_tc, tiles_tc) 'find possible collisions
				for ti in tiles_tc
					tid = tiles_tc(ti)
					if tid > 0 then
						cr_tile(anActor, a_op, mapTiles(tid), ti)
						'push(cps,ti); 'REMOVE ME LATER
						rerun = true;
						rrcount = rrcount + 1
						'exit
					endif
				next
				if rrcount > rrmax then
					rerun = false
				endif
			wend
		
			
			'Change velocity of character based on simple physics
			phy_result = apply_physics(anActor)
			anActor.v = phy_result
			
			'Round Position Values for smoother movement
			unpack (anActor.p, a_px, a_py)
			anActor.p = vec2(round(a_px), round(a_py))
			
			if time > 5 then 'Every second check if an actor is out of bounds
				check_oob(anActor)
			endif
		next
		
		if time > 5 then 'every second delete out of bounds actors
			rmv_oobs()
		endif
		
		'printGrid()
		clearGridState()
	enddef
	
	def init_grid(m, x, y)'map, size x, size y
		gridsize = vec2(x, y)
		
		for ix = 0 to x/gridRes-1 step 1
			tempList_x = list()
			push(grid, tempList_x)
			for iy = 0 to y/gridRes-1 step 1
				tempList_y = list()
				push(grid(ix), tempList_y)
			next
		next
	enddef
	
	def init_actors(actorDict)
		if actorDict <> nil then
			actors = actorDict
		endif
	enddef
	
	def init_mapTiles()
		tile0 = new(collix_mapTile)
		tile0.init(0, true, vec2(0,0), vec2(8,8))
		set(mapTiles, 0, tile0)
		
		tile1 = new(collix_mapTile)
		tile1.init(1, false, vec2(0,0), vec2(8,8))
		set(mapTiles, 1, tile1)
		
		tile2 = new(collix_mapTile)
		tile2.init(2, false, vec2(0,2), vec2(8,4))
		set(mapTiles, 2, tile2)
		
		tile3 = new(collix_mapTile)
		tile3.init(3, false, vec2(0,4), vec2(8,4))
		set(mapTiles, 3, tile3)
		
		tile4 = new(collix_mapTile)
		tile4.init(4, false, vec2(0,0), vec2(8,4))
		set(mapTiles, 4, tile4)
	enddef
	
	def getGridTile(x, y)
		return get(get(grid, x), y)
	enddef
	
	def setGridState()
		unpack(gridsize, gx, gy)
		gx = gx/gridRes
		gy = gy/gridRes
		for a in actors
			anActor = actors(a)
			unpack(anActor.p, px, py)
			mPx = floor(px/8/gridRes)
			mPy = floor(py/8/gridRes)
			if mPx < 0 or mPx > gx or mPy < 0 or mPy > gy then
				'do nothing, out of bounds
			else
				tile = me.getGridTile( mPx, mPy )
				if exists(tile, anActor.id) = false then
					push(tile, anActor.id)
				endif
			endif
		next
	enddef
	
	def clearGridState()
		unpack(gridsize, x, y)
		for ix = 0 to x/gridRes-1 step 1
			for iy = 0 to y/gridRes-1 step 1
				tile = get(get(grid, ix), iy)
				tile = dict()
			next
		next
	enddef
	
	def scan_map(obj, actors_rec, tile_rec)
		unpack(gridsize, gx, gy)
		unpack(obj.p, px, py)
		unpack(obj.v, vx, vy)
		unpack(obj.bb_wh, w, h)
		
		rpx = floor(px/8)
		rpy = floor(py/8)
		rpxw = floor((px+w)/8)
		rpyh = floor((py+h)/8)
		rcentx = floor((px+w/2)/8)
		rcenty = floor((py+h/2)/8)
		icw = ceil(pw/8) 'If > 1 needs extra checks
		ich = ceil(ph/8) 'If > 1 needs extra checks

		'print rpx, " ", rpxw, " ",  rpy, " ", rpyh;
		if rpx >= gx-icw or rpx < 0 or rpy >= gy-icw or rpy < 0 then
			'out of bounds, dont check for collision
		else
			'get tiles to check collison with
			'TODO add icw ich extra checks if too big (px+0.25*w, px+0.75*w...)
			t_tl = mget amap, 0, rpx, rpy
			t_tr = mget amap, 0, rpxw, rpy
			t_br = mget amap, 0, rpxw, rpyh
			t_bl = mget amap, 0, rpx, rpyh
			t_cen = mget amap, 0, rcentx, rcenty
		
			'Sorted by movement direction
			if vx > 0 and vy > 0 then 'botright
				set(tile_rec, vec2(rpxw, rpyh), t_br)
				set(tile_rec, vec2(rpx, rpyh), t_bl)
				set(tile_rec, vec2(rpxw, rpy), t_tr)
				set(tile_rec, vec2(rcentx, rcenty), t_cen)
				set(tile_rec, vec2(rpx, rpy), t_tl)
			elseif vx < 0 and vy < 0 then 'topleft
				set(tile_rec, vec2(rpx, rpy), t_tl)
				set(tile_rec, vec2(rpxw, rpy), t_tr)
				set(tile_rec, vec2(rpx, rpyh), t_bl)
				set(tile_rec, vec2(rcentx, rcenty), t_cen)
				set(tile_rec, vec2(rpxw, rpyh), t_br)
			elseif vx > 0 and vy < 0 then 'topright
				set(tile_rec, vec2(rpxw, rpy), t_tr)
				set(tile_rec, vec2(rpx, rpy), t_tl)
				set(tile_rec, vec2(rpxw, rpyh), t_br)
				set(tile_rec, vec2(rcentx, rcenty), t_cen)
				set(tile_rec, vec2(rpx, rpyh), t_bl)
			elseif vx < 0 and vy > 0 then 'bottomleft
				set(tile_rec, vec2(rpx, rpyh), t_bl)
				set(tile_rec, vec2(rpx, rpy), t_tl)
				set(tile_rec, vec2(rpxw, rpyh), t_br)
				set(tile_rec, vec2(rcentx, rcenty), t_cen)
				set(tile_rec, vec2(rpxw, rpy), t_tr)
			elseif vx > 0 and vy = 0 then 'right
				set(tile_rec, vec2(rpxw, rpyh), t_br)
				set(tile_rec, vec2(rpxw, rpy), t_tr)
				set(tile_rec, vec2(rcentx, rcenty), t_cen)
				set(tile_rec, vec2(rpx, rpyh), t_bl)
				set(tile_rec, vec2(rpx, rpy), t_tl)
			elseif vx = 0 and vy > 0 then 'bottom
				set(tile_rec, vec2(rpx, rpyh), t_bl)
				set(tile_rec, vec2(rpxw, rpyh), t_br)
				set(tile_rec, vec2(rcentx, rcenty), t_cen)
				set(tile_rec, vec2(rpx, rpy), t_tl)
				set(tile_rec, vec2(rpxw, rpy), t_tr)
			elseif vx < 0 and vy = 0 then 'left
				set(tile_rec, vec2(rpx, rpy), t_tl)
				set(tile_rec, vec2(rpx, rpyh), t_bl)
				set(tile_rec, vec2(rcentx, rcenty), t_cen)
				set(tile_rec, vec2(rpxw, rpyh), t_br)
				set(tile_rec, vec2(rpxw, rpy), t_tr)
			elseif vx = 0 and vy < 0 then 'top
				set(tile_rec, vec2(rpx, rpy), t_tl)
				set(tile_rec, vec2(rpxw, rpy), t_tr)
				set(tile_rec, vec2(rcentx, rcenty), t_cen)
				set(tile_rec, vec2(rpxw, rpyh), t_br)
				set(tile_rec, vec2(rpx, rpyh), t_bl)
			else
				set(tile_rec, vec2(rpx, rpy), t_tl)
				set(tile_rec, vec2(rpxw, rpy), t_tr)
				set(tile_rec, vec2(rpxw, rpyh), t_br)
				set(tile_rec, vec2(rpx, rpyh), t_bl)
				set(tile_rec, vec2(rcentx, rcenty), t_cen)
			endif
			
			'Actor collision here
			'myChuck = 
			
			mPx = floor(px/8/gridRes)
			mPy = floor(py/8/gridRes)
			'print mPx, mPy
			gridtile = me.getGridTile(mPx, mPy)
			
		endif
	enddef

	def cr_actor(obj_a, a_op, obj_b) 'cr = check and resolve (aabb) collision
		unpack(obj_a.p, a_px, a_py)
		unpack(obj_a.v, a_vx, a_vy)
		unpack(obj_a.bb_wh, a_w, a_h)
		unpack(obj_a.bb_o, a_bb_ox, a_bb_oy)
		unpack(a_op, a_old_px, a_old_py) 'old/initial position before movement happened
		
		unpack(obj_b.p, b_px, b_py)
		unpack(obj_b.v, b_vx, b_vy)
		unpack(obj_b.bb_wh, b_w, b_h)
		unpack(obj_b.bb_o, b_bb_ox, b_bb_oy)
		
		b_px_bb = b_px + b_bb_ox
		b_py_bb = b_px + b_bb_oy
		b_c = vec2(round(b_px_bb + b_w/2), round(b_py_bb + b_h/2))
		unpack(b_c, b_cx, b_cy)
		unpack(normalize(a_old_c - b_c), dir_x, dir_y)
		
		
		hasColl = false
		if a_px < b_px + b_w and a_px + a_w > b_px and a_py < b_py + b_h and a_py + a_h > b_py then
		
		'check x-axis
			if dir_x < 0 then 'a is left from b
				distx = abs((a_px_bb + a_w) - (b_px_bb))
			elseif dir_x > 0 then
				distx = abs(a_px_bb - (b_px_bb + b_w))
			else
				distx = abs(a_px_bb - (b_px_bb + b_w)) + abs((a_px_bb + a_w) - (b_px_bb)) - abs(a_w)
			endif
			
		'check y-axis
			if dir_y < 0 then 'a is above b
				disty = abs((a_py_bb + a_h) - (b_py_bb))
			elseif dir_y > 0 then
				disty = abs(a_py_bb - (b_py_bb + b_h))
			else
				disty = abs(a_py_bb - (b_py_bb + b_h)) + abs((a_py_bb + a_h) - (b_py_bb)) - abs(a_h)
			endif
			
			'print dir_x, " dir ", dir_y;
			'print distx, " dist ", disty;
			
		'collision Response	
			if distx < disty then 'push out x
				if dir_x < 0 then
					obj_a.p = vec2((b_px_bb - a_w), a_py)
				elseif dir_x > 0 then
					obj_a.p = vec2((b_px_bb + b_w), a_py)
				else
					obj_a.p = vec2((b_px_bb - a_w), a_py)
				endif
				hitLoc = 3
			else 'push out y
				if dir_y < 0 then
					obj_a.p = vec2(a_px, (b_py_bb - a_h))
					hitLoc = 1
				elseif dir_y > 0 then
					obj_a.p = vec2(a_px, (b_py_bb + b_h))
					hitLoc = 2
				else
					obj_a.p = vec2(a_px, (b_py_bb - a_h))
					hitLoc = 1
				endif
			endif
			
			if hitLoc = 1 then
				set(obj_a.tags, 1, 1)
			elseif hitLoc = 2 then
				set(obj_a.tags, 2, 1)
			elseif hitloc = 3 then
				set(obj_a.tags, 3, 1)
			endif
			
		endif
		'TODO Also return list of flags yo
	enddef
	
	def cr_tile(obj_a, a_op, tile, tilepos)
		unpack(obj_a.p, a_px, a_py)
		unpack(obj_a.v, a_vx, a_vy)
		unpack(obj_a.bb_o, a_bb_ox, a_bb_oy)
		unpack(obj_a.bb_wh, a_w, a_h)
		unpack(a_op, a_old_px, a_old_py) 'old/initial position before movement happened
		a_c = vec2(round(a_px + a_bb_ox + a_w/2), round(a_py + a_bb_oy + a_h/2))
		a_old_c = vec2(round(a_old_px + a_bb_ox + a_w/2), round(a_old_py + a_bb_oy + a_h/2))
		a_px_bb = a_px + a_bb_ox
		a_py_bb = a_py + a_bb_oy
		
		unpack(tilepos, b_px, b_py)
		unpack(tile.bb_o, b_bb_ox, b_bb_oy)
		unpack(tile.bb_wh, b_w, b_h)
		b_px_bb = b_px*8 + b_bb_ox
		b_py_bb = b_py*8 + b_bb_oy
		b_px = b_px*8
		b_py = b_py*8
		b_c = vec2(round(b_px_bb + b_w/2), round(b_py_bb + b_h/2))
		unpack(b_c, b_cx, b_cy)
		unpack(normalize(a_old_c - b_c), dir_x, dir_y)
		
		'print b_cx, " ", b_cy;
		
		if a_px_bb < b_px_bb + b_w and a_px_bb + a_w > b_px_bb and a_py_bb < b_py_bb + b_h and a_py_bb + a_h > b_py_bb then	'did collide
			distx = nil
			disty = nil
			hitLoc = nil '0 top 1/3 right 2 bot 3/1 left
			
		'check x-axis
			if dir_x < 0 then 'a is left from b
				distx = abs((a_px_bb + a_w) - (b_px_bb))
			elseif dir_x > 0 then
				distx = abs(a_px_bb - (b_px_bb + b_w))
			else
				distx = abs(a_px_bb - (b_px_bb + b_w)) + abs((a_px_bb + a_w) - (b_px_bb)) - abs(a_w)
			endif
			
		'check y-axis
			if dir_y < 0 then 'a is above b
				disty = abs((a_py_bb + a_h) - (b_py_bb))
			elseif dir_y > 0 then
				disty = abs(a_py_bb - (b_py_bb + b_h))
			else
				disty = abs(a_py_bb - (b_py_bb + b_h)) + abs((a_py_bb + a_h) - (b_py_bb)) - abs(a_h)
			endif
			
			'print dir_x, " dir ", dir_y;
			'print distx, " dist ", disty;
			
		'collision Response	
			if distx < disty then 'push out x
				if dir_x < 0 then
					obj_a.p = vec2((b_px_bb - a_w), a_py)
				elseif dir_x > 0 then
					obj_a.p = vec2((b_px_bb + b_w), a_py)
				else
					obj_a.p = vec2((b_px_bb - a_w), a_py)
				endif
				hitLoc = 3
			else 'push out y
				if dir_y < 0 then
					obj_a.p = vec2(a_px, (b_py_bb - a_h))
					hitLoc = 1
				elseif dir_y > 0 then
					obj_a.p = vec2(a_px, (b_py_bb + b_h))
					hitLoc = 2
				else
					obj_a.p = vec2(a_px, (b_py_bb - a_h))
					hitLoc = 1
				endif
			endif
			
			if hitLoc = 1 then
				set(obj_a.tags, 1, 1)
			elseif hitLoc = 2 then
				set(obj_a.tags, 2, 1)
			elseif hitloc = 3 then
				set(obj_a.tags, 3, 1)
			endif
			
		endif
	enddef
	
	def check_oob(anActor)
		unpack(anActor.p, px, py)
		if px < -1*8 or px > 128*8 or py < -1*8 or py > 32*8 then
			push(toBeRemoved, anActor.id)
		endif
	enddef
	
	def rmv_oobs()
		for rmvId in toBeRemoved
			remove(actors, rmvId)
		next
		'toBeRemoved = list()
		clear(toBeRemoved)
	enddef

	def apply_movement(a)
		unpack(a.p, px, py);
		unpack(a.v, vx, vy);
		px = round(px + vx)
		py = round(py + vy)
		return vec2(px,py)
	enddef
	
	def apply_physics(a)'@p = position = vec2 /@v = velocity = vec2
		unpack(a.p, px, py);
		unpack(a.v, vx, vy);
		
		'sgn(vx); 'Direction: -1 = left | 0 | +1 = right
		'sgn(vy) 'Direction: -1 = up | 0 | +1 = down
		'abs(vx) && abs(vy) 'Absolute value for accurate caluculations, use in if-statement
		
		if abs(vx) <= 0.01 then
			vx = 0
		else
			vx = vx * friction
		endif
		
		if a.onGround = true and sgn(vy) <> -1 then
			vy = 0
		elseif vy < a.ms_y then
			vy = vy + gravity
		endif
		
		
		return vec2(vx,vy)
	enddef
	
	def printGrid()
		unpack(gridsize, x, y)
		x = x/gridRes-1
		y = y/gridRes-1
		print "GRIDBEGIN";
		for iy = 0 to y step 1
			for ix = 0 to x step 1
				if len(get(get(grid,ix),iy)) = 0 then
					print "0"
				else
					print "1"
				endif
			next
			print "";
		next
	enddef
endclass

'---- ACTOR CLASS ---
class actor
	var id = nil
	var prio = false 'if true checks collision more accurate. Should be used for the player and fast objects
	var sprite = load_resource("colli.sprite")
	var p = vec2(0,0)
	var v = vec2(0,0)
	var bb_o = vec2(0,0) 'Boundingbox origin
	var bb_wh = vec2(0,0) 'Bounding box width and height
	
	var ms_x = 4
	var ms_y = 4
	var hasPhysics = true
	var isGhost = false
	var mass = 100
	var bouncy = 0
	
	var onGround = false
	
	var emitTag = 0 'Tag to give other objects when colliding ( 0-9 reserved, number 10 for "Damage" for example)
	var tags = dict()
	
	def upd(aMap)'character logic goes here
		onGround = false;
		check_ground(aMap)
		processTags()
	enddef
	
	def check_ground(aMap)
		unpack(p, px, py)
		unpack(bb_o, ox, oy)
		unpack(bb_wh, w, h)
		gpixel_x = px+ox
		gpixel_y = py+oy+h+1

		for i = 0 to w-1 step 1
			tileindex = mget aMap, 0, gpixel_x/8, gpixel_y/8
			if tileindex >= 1 then
				onGround = true
				exit
			else
				gpixel_x = gpixel_x + 1
			endif
		next
	enddef
	
	def processTags() 'processes given tags
		unpack(v, vx, vy)
		for tag in tags
			tagCount = tags(tag)
			if tag = 2 then
				v = vec2(vx, vy*0.2)
			elseif tag = 3 and onGround = false and abs(vx) > 3 then
				v = vec2(vx*-0.5, vy)
			endif
		next
		clear(tags)
	enddef
	
	def init(idList, position, velocity, bbox_origin, bbox_wh)
		id = register(idList)
		p = position
		old_p = position
		v = velocity
		bb_o = bbox_origin
		bb_wh = bbox_wh
		unpack(bbox_wh, w, h)
		ms_x = 4 'max speed x
		ms_y = 4 'max speed y
		return id;
	enddef
	
	def rmv(actorDict)
		print "Object removed, id was: " + str(id);
		remove(actorDict, id);
	enddef
	
	def register(idDict)
		idExists = true
		t_id = nil
		while idExists = true
			t_id = rnd(16,999)
			idExists = exists(idDict, t_id) 
		wend
		id = t_id
		set(idDict, id, me)
		return id;
	enddef
	
	def debugInfo()
		unpack(p, px, py)
		unpack(v, vx, vy)
		print "ID:" + str(id) + " P:" + str(px) + "/" + str(py) + " V:" + str(vx) + "/" + str(vy), " Grnd:" + str(onGround);
	enddef
endclass

class colli(actor) 'a 16x16 character
	sprite = load_resource("colli.sprite")
	var sId = 1
	var anim = play(me.sprite, 1, 1, 1, false)

endclass

class smolColli(actor)
	sprite = load_resource("smolColli.sprite")
	var sId = 1
	var anim = play(me.sprite, 1, 1, 1, false)
endclass


'---- GLOBAL VARIABLES ----
t = 0
t2 = 0
tc = 0
cam_p = vec2(0,128)
pause = false

'---- Object Management ----
actor_objects = dict()

'---- Create Actors & Init them ----
'Playable char
	psId = rnd(1,10)
	player = new(smolColli)
	player.anim = play(player.sprite, psId, psId, 1, false)
	playerid = player.init(actor_objects, vec2(rnd(4,16)*8, rnd(4,16)*8), vec2(0,0), vec2(0,0), vec2(8,8))

for i = 1 to 0 step 1
	sId = rnd(1,2)
	o = new(colli)
	o.anim = play(o.sprite, sId, sId, 1, false)
	poi = vec2(rnd(4,16)*8, rnd(4,16)*8)
	vel = vec2(0,0)
	bbox_o = vec2(0,0)
	bbox_wh = vec2(16,16)
	'(idList, position, velocity, bbox_tl, bbox_br)
	o.init(actor_objects, poi, vel, bbox_o, bbox_wh)
	'o.debugInfo()
next

for i2 = 1 to 25 step 1
	sId = rnd(1,10)
	o = new(smolColli)
	o.anim = play(o.sprite, sId, sId, 1, false)
	poi = vec2(rnd(4,32)*8, rnd(4,16)*8)
	vel = vec2(0,0)
	bbox_o = vec2(0,0)
	bbox_wh = vec2(8,8)
	o.init(actor_objects, poi, vel, bbox_o, bbox_wh)
	'o.debugInfo()
next

'---- Init Collix ----
collix = new(collix_engine);
collix.init(rMap, 64, 32, actor_objects)
'collix.printGridStatic()

'---- GAME LOOPS ----
def update(delta)
	t = t + delta
	tc = tc + delta
	t2 = t2 + delta
	
	player = get(actor_objects , playerId)
	if btn() then
		if btn(0) and player.onGround = true then
			player.v = player.v + vec2(-0.8, 0)
		elseif btn(0) and player.onGround = false then
			player.v = player.v + vec2(-0.5, 0)
		endif
		if btn(1) and player.onGround = true then
			player.v = player.v + vec2(0.8, 0)
		elseif btn(1) and player.onGround = false then
			player.v = player.v + vec2(0.5, 0)
		endif
		if btn(2) and player.onGround = true then
			player.v = player.v + vec2(0, -3)
		endif
		if btn(3) then
			player.v = player.v + vec2(0, 1)
		endif
		if btn(4) then
			pause = true
		endif
		if btn(5) then
			pause = false
		endif
		player.debugInfo()
	endif
	
	if t > 1 then
		t = t - 1
		for a in actor_objects 'actors jump randomly every second
			anActor = actor_objects(a)
			if anActor.id <> playerId and anActor.onGround = true then
				anActor.v = anActor.v + vec2(0,rnd(-7,-4))
			endif
		next
		
		print "===[ DEBUG INFO ]===";
		print "Actors Alive: " + str(len(actor_objects));
		print "Delta: " + str(delta*30) + " " + str(delta);
		print "Time: " + str(t);
		print "Memory-MB: " + str(mem/1000000);
		print "";
		clear(cps)
		col rgba(rnd(255), rnd(255), rnd(255), 127)
	endif
	
	
	if t2 > 0.05 then
		t2 = t2 - 0.05
		for a in actor_objects 'Move actors randomly
			anActor = actor_objects(a)
			if anActor.id <> playerId then
				unpack(anActor.v, vx, vy)
				if vx >= 0 then
					rn = rnd(0,100)
					if rn >= 20 then
						anActor.v = anActor.v + vec2(rnd(1,2),0)
					else
						anActor.v = anActor.v + vec2(rnd(-3,-1),0)
					endif
				elseif vx < 0 then
					rn = rnd(0,100)
					if rn >= 80 then
						anActor.v = anActor.v + vec2(rnd(1,2),0)
					else
						anActor.v = anActor.v + vec2(rnd(-3,-1),0)
					endif
				endif
			endif
		next
	endif
	
	
	'Update Actors
	for a in actor_objects
		anActor = actor_objects(a)
		anActor.upd(rMap)
	next
	
	'Render Map
	unpack(cam_p, cam_x, cam_y)
	unpack(player.p, playerp_x, playerp_y)
	camera (floor(playerp_x) - 63), (floor(playerp_y) - 100)
	cam_p = vec2(floor(playerp_x) - 63, floor(playerp_y) - 100)
	map rMap, 0, 0, 0
	text cam_x, cam_y, len(actor_objects), rgba(0,0,0,255)
	
	if pause = false then
		collix.run(tc)
	endif
	
	if tc > 5 then
		tc = tc - 5
	endif
	
	'draw collisions
	
	'[for cp in cps
		unpack(cp, x, y)
		rectfill x*8, y*8, x*8+7, y*8+7, rgba(120,0,0,255)
	next']
	
	
	'Render sprites
	for a in actor_objects
		anActor = actor_objects(a)
		unpack(anActor.p, px, py)
		spr anActor.sprite, px, py, 0
	next
enddef


'---- UPDATE FUNCTION ----
update_with(drv, call(update))
