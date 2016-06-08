require "./AI/Const.lua"
require "./AI/Util.lua"					

-----------------------------
-- state
-----------------------------
IDLE_ST					= 0
CHASE_ST				= 2
ATTACK_ST				= 3
MOVE_CMD_ST				= 4
STOP_CMD_ST				= 5
ATTACK_OBJECT_CMD_ST			= 6
ATTACK_AREA_CMD_ST			= 7
PATROL_CMD_ST				= 8
SKILL_OBJECT_CMD_ST			= 10
SKILL_AREA_CMD_ST			= 11
FOLLOW_CMD_ST				= 12
----------------------------



------------------------------------------
-- global variable
------------------------------------------
MyState				= IDLE_ST	-- 최초의 상태는 휴식
MyEnemy				= 0		-- 적 id
MyDestX				= 0		-- 목적지 x
MyDestY				= 0		-- 목적지 y
MyPatrolX			= 0		-- 정찰 목적지 x
MyPatrolY			= 0		-- 정찰 목적지 y
ResCmdList			= List.new()	-- 예약 명령어 리스트 
MyID				= 0		-- 호문클루스 id
MySkill				= 0		-- 호문클루스의 스킬
MySkillLevel			= 0		-- 호문클루스의 스킬 레벨
------------------------------------------



MyMob = "힐 윈드"
MyBestSkill = 46
MyBestSkillLevel = 5
MySP = 12
MyHP = 1600
MyMap = "payon.gat"





------------- command process  ---------------------

function	OnMOVE_CMD (x,y)
	
	TraceAI ("OnMOVE_CMD")

	if ( x == MyDestX and y == MyDestY and MOTION_MOVE == GetV(V_MOTION,MyID)) then
		return		-- 현재 이동중인 목적지와 같은 곳이면 처리하지 않는다. 
	end

	local curX, curY = GetV (V_POSITION,MyID)
	if (math.abs(x-curX)+math.abs(y-curY) > 15) then		-- 목적지가 일정 거리 이상이면 (서버에서 먼거리는 처리하지 않기 때문에)
		List.pushleft (ResCmdList,{MOVE_CMD,x,y})			-- 원래 목적지로의 이동을 예약한다. 	
		x = math.floor((x+curX)/2)							-- 중간지점으로 먼저 이동한다.  
		y = math.floor((y+curY)/2)							-- 
	end

	Move (MyID,x,y)	
	
	MyState = MOVE_CMD_ST
	MyDestX = x
	MyDestY = y
	MyEnemy = 0
	MySkill = 0

end




function	OnSTOP_CMD ()

	TraceAI ("OnSTOP_CMD")

	if (GetV(V_MOTION,MyID) ~= MOTION_STAND) then
		Move (MyID,GetV(V_POSITION,MyID))
	end
	MyState = IDLE_ST
	MyDestX = 0
	MyDestY = 0
	MyEnemy = 0
	MySkill = 0

end




function	OnATTACK_OBJECT_CMD (id)

	TraceAI ("OnATTACK_OBJECT_CMD")

	MySkill = 0
	MyEnemy = id
	MyState = CHASE_ST

end




function	OnATTACK_AREA_CMD (x,y)

	TraceAI ("OnATTACK_AREA_CMD")

	if (x ~= MyDestX or y ~= MyDestY or MOTION_MOVE ~= GetV(V_MOTION,MyID)) then
		Move (MyID,x,y)	
	end
	MyDestX = x
	MyDestY = y
	MyEnemy = 0
	MyState = ATTACK_AREA_CMD_ST
	
end



function	OnPATROL_CMD (x,y)

	TraceAI ("OnPATROL_CMD")

	MyPatrolX , MyPatrolY = GetV (V_POSITION,MyID)
	MyDestX = x
	MyDestY = y
	Move (MyID,x,y)
	MyState = PATROL_CMD_ST

end




function	OnSKILL_OBJECT_CMD (level,skill,id)

	TraceAI ("OnSKILL_OBJECT_CMD")

	MySkillLevel = level
	MySkill = skill
	MyEnemy = id
	MyState = CHASE_ST

end




function	OnSKILL_AREA_CMD (level,skill,x,y)

	TraceAI ("OnSKILL_AREA_CMD")

	Move (MyID,x,y)
	MyDestX = x
	MyDestY = y
	MySkillLevel = level
	MySkill = skill
	MyState = SKILL_AREA_CMD_ST
	
end




function	ProcessCommand (msg)

	if		(msg[1] == MOVE_CMD) then
		OnMOVE_CMD (msg[2],msg[3])
		TraceAI ("MOVE_CMD")
	elseif	(msg[1] == STOP_CMD) then
		OnSTOP_CMD ()
		TraceAI ("STOP_CMD")
	elseif	(msg[1] == ATTACK_OBJECT_CMD) then
		OnATTACK_OBJECT_CMD (msg[2])
		TraceAI ("ATTACK_OBJECT_CMD")
	elseif	(msg[1] == ATTACK_AREA_CMD) then
		OnATTACK_AREA_CMD (msg[2],msg[3])
		TraceAI ("ATTACK_AREA_CMD")
	elseif	(msg[1] == PATROL_CMD) then
		OnPATROL_CMD (msg[2],msg[3])
		TraceAI ("PATROL_CMD")
	elseif	(msg[1] == SKILL_OBJECT_CMD) then
		OnSKILL_OBJECT_CMD (msg[2],msg[3],msg[4],msg[5])
		TraceAI ("SKILL_OBJECT_CMD")
	elseif	(msg[1] == SKILL_AREA_CMD) then
		OnSKILL_AREA_CMD (msg[2],msg[3],msg[4],msg[5])
		TraceAI ("SKILL_AREA_CMD")
	end
end




-------------- state process  --------------------


function	OnIDLE_ST ()
	
	TraceAI ("OnIDLE_ST")

	local cmd = List.popleft(ResCmdList)
	if (cmd ~= nil) then		
		ProcessCommand (cmd)	-- 예약 명령어 처리 
		return 
	end

	object = GetMyItem (MyID)
	if (object ~= 0) then							-- ATTACKED_IN
		ItemPickUp ( object )
		MyState = CHASE_ST
		return
	end

	object = GetMyEnemy (MyID)
	if (object ~= 0) then							-- ATTACKED_IN
		MyState = CHASE_ST
		MyEnemy = object
		TraceAI ("IDLE_ST -> CHASE_ST : ATTACKED_IN")
		return
	else
		MoveToMap ("") 
		MyState = IDLE_ST
		MyEnemy = 0
		return	
	end

end


function	OnCHASE_ST ()

	TraceAI ("OnCHASE_ST")

	if (true == IsOutOfSight(MyID,MyEnemy)) then	-- ENEMY_OUTSIGHT_IN
		MyState = IDLE_ST
		MyEnemy = 0
		MyDestX, MyDestY = 0,0
		TraceAI ("CHASE_ST -> IDLE_ST : ENEMY_OUTSIGHT_IN")
		return
	end
	if (true == IsInAttackSight(MyID,MyEnemy)) then  -- ENEMY_INATTACKSIGHT_IN
		MyState = ATTACK_ST
		TraceAI ("CHASE_ST -> ATTACK_ST : ENEMY_INATTACKSIGHT_IN")
		return
	end

	local x, y = GetV (V_POSITION,MyEnemy)
	if (MyDestX ~= x or MyDestY ~= y) then			-- DESTCHANGED_IN
		MyDestX, MyDestY = GetV (V_POSITION,MyEnemy);
		Move (MyID,MyDestX,MyDestY)
		TraceAI ("CHASE_ST -> CHASE_ST : DESTCHANGED_IN")
		return
	else
		MoveToMap ("") 
		return	
	end
end




function	OnATTACK_ST ()

	TraceAI ("OnATTACK_ST")
	
	if (true == IsOutOfSight(MyID,MyEnemy)) then	-- ENEMY_OUTSIGHT_IN
		MyState = IDLE_ST
		TraceAI ("ATTACK_ST -> IDLE_ST")
		return 
	end

	if (MOTION_DEAD == GetV(V_MOTION,MyEnemy)) then   -- ENEMY_DEAD_IN
		MyState = IDLE_ST
		TraceAI ("ATTACK_ST -> IDLE_ST")
		return
	end
		
	if (false == IsInAttackSight(MyID,MyEnemy)) then  -- ENEMY_OUTATTACKSIGHT_IN
		MyState = CHASE_ST
		MyDestX, MyDestY = GetV (V_POSITION,MyEnemy);
		Move (MyID,MyDestX,MyDestY)
		TraceAI ("ATTACK_ST -> CHASE_ST  : ENEMY_OUTATTACKSIGHT_IN")
		return
	end
	
	local hp = GetV (V_HP,MyID)
	if ( hp < MyHP ) then 
		MoveToMap ( MyMap )
		return 
	end

	local sp = GetV (V_SP,MyID)
	if ( MyBestSkill ~= 0 and sp > MySP ) then
		SkillObject (MyID,MyBestSkillLevel,MyBestSkill,MyEnemy)
		return 
	end

	if (MySkill == 0) then
		Attack (MyID,MyEnemy)
	else
		SkillObject (MyID,MySkillLevel,MySkill,MyEnemy)
		MySkill = 0
	end
	TraceAI ("ATTACK_ST -> ATTACK_ST  : ENERGY_RECHARGED_IN")
	return


end




function	OnMOVE_CMD_ST ()

	TraceAI ("OnMOVE_CMD_ST")

	local x, y = GetV (V_POSITION,MyID)
	if (x == MyDestX and y == MyDestY) then				-- DESTINATION_ARRIVED_IN
		MyState = IDLE_ST
	end
end


function OnATTACK_AREA_CMD_ST ()

	TraceAI ("OnATTACK_AREA_CMD_ST")

	local	object = GetMyEnemy (MyID) 

	if (object ~= 0) then							-- ATTACKED_IN
		MyState = CHASE_ST
		MyEnemy = object
		return
	end

	local x , y = GetV (V_POSITION,MyID)
	if (x == MyDestX and y == MyDestY) then			-- DESTARRIVED_IN
			MyState = IDLE_ST
	end

end




function OnPATROL_CMD_ST ()

	TraceAI ("OnPATROL_CMD_ST")

	local	object = GetMyEnemy (MyID) 

	if (object ~= 0) then							-- MYOWNER_ATTACKED_IN or ATTACKED_IN
		MyState = CHASE_ST
		MyEnemy = object
		TraceAI ("PATROL_CMD_ST -> CHASE_ST : ATTACKED_IN")
		return
	end

	local x , y = GetV (V_POSITION,MyID)
	if (x == MyDestX and y == MyDestY) then			-- DESTARRIVED_IN
		MyDestX = MyPatrolX
		MyDestY = MyPatrolY
		MyPatrolX = x
		MyPatrolY = y
		Move (MyID,MyDestX,MyDestY)
		return 
	end

	Move (MyID,x+1,y+1)
end




function OnSKILL_AREA_CMD_ST ()

	TraceAI ("OnSKILL_AREA_CMD_ST")

	local x , y = GetV (V_POSITION,MyID)
	if (GetDistance(x,y,MyDestX,MyDestY) <= GetV(V_SKILLATTACKRANGE,MyID,MySkill)) then	-- DESTARRIVED_IN
		SkillGround (MyID,MySkillLevel,MySkill,MyDestX,MyDestY)
		MyState = IDLE_ST
		MySkill = 0
	end

end

function	GetMyItem (myid)
	local result = 0
	local items = GetItems ()

	local min_dis = 100
	local dis
	for i,v in ipairs(items) do
		dis = GetDistance2 (myid,v)
		if (dis < min_dis) then
			result = v
			min_dis = dis
		end
	end

	return result
end




function	GetMyEnemy (myid)
	local result = GetMyEnemyB (myid)

	if ( IsMyMonster ( result, MyMob ) ~= 1 ) then
		result = 0
	end

	return result

end


-------------------------------------------
--  선공형 GetMyEnemy
-------------------------------------------
function	GetMyEnemyB (myid)
	local result = 0
	local actors = GetActors ()
	local enemys = {}
	local index = 1
	local type
	for i,v in ipairs(actors) do
		--if (v ~= myid) then
			if (1 == IsMonster(v))	then
				enemys[index] = v
				index = index+1
			end
		--end
	end

	local min_dis = 100
	local dis
	for i,v in ipairs(enemys) do
		dis = GetDistance2 (myid,v)
		if (dis < min_dis) then
			result = v
			min_dis = dis
		end
	end

	return result
end



function AI(myid)

	MyID = myid
	local msg	= GetMsg (myid)			-- command
	local rmsg	= GetResMsg (myid)		-- reserved command
	
	if msg[1] == NONE_CMD then
		if rmsg[1] ~= NONE_CMD then
			if List.size(ResCmdList) < 10 then
				List.pushright (ResCmdList,rmsg) -- 예약 명령 저장
			end
		end
	else
		List.clear (ResCmdList)	-- 새로운 명령이 입력되면 예약 명령들은 삭제한다.  
		ProcessCommand (msg)	-- 명령어 처리 
	end

		
	-- 상태 처리 
 	if (MyState == IDLE_ST) then
		OnIDLE_ST ()
	elseif (MyState == CHASE_ST) then					
		OnCHASE_ST ()
	elseif (MyState == ATTACK_ST) then
		OnATTACK_ST ()
	elseif (MyState == MOVE_CMD_ST) then
		OnMOVE_CMD_ST ()
	elseif (MyState == ATTACK_AREA_CMD_ST) then
		OnATTACK_AREA_CMD_ST ()
	elseif (MyState == PATROL_CMD_ST) then
		OnPATROL_CMD_ST ()
	elseif (MyState == SKILL_OBJECT_CMD_ST) then
		OnSKILL_OBJECT_CMD_ST ()
	elseif (MyState == SKILL_AREA_CMD_ST) then
		OnSKILL_AREA_CMD_ST ()
	end

end
