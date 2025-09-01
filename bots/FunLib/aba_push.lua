local Push = {}

local J          = require(GetScriptDirectory()..'/FunLib/jmz_func')
local Customize  = require(GetScriptDirectory()..'/Customize/general')
Customize.ThinkLess = Customize.Enable and Customize.ThinkLess or 1

-- Tunables / thresholds
local pingTimeDelta      = 5
local StartToPushTime    = 16 * 60 -- after X mins, start considering to push.
local BOT_MODE_DESIRE_EXTRA_LOW = 0.02

-- Module-scoped state (cache-ish). Keep small and intentional.
local hEnemyAncient = nil

-- === Objective selection stability (anti-thrash) ===
local OBJECTIVE_STICKY_TIME    = 1.2    -- seconds to keep current target before reconsidering
local SWITCH_SCORE_MARGIN      = 0.25   -- how much better (lower) the new score must be to switch
local OBJECTIVE_LEASH_RANGE    = 2600   -- max distance from bot to consider high-ground objectives

-- Barracks ≈ 200 from T3, T4 ≈ 800 from barracks; favor inner-ring first
-- Lower score is better. Priority: Barracks (melee>ranged) < T3 < Fillers < T4
local SCORE_BARRACKS_MELEE     = 0
local SCORE_BARRACKS_RANGED    = 0.1
local SCORE_T3                 = 0.5
local SCORE_FILLER             = 0.8
local SCORE_T4                 = 1.2

-- Add per-bot, per-lane objective memory
-- Example: ObjectiveState[playerID][lane] = { target=hUnit, lockUntil=GameTime() }
local ObjectiveState = {}

--------------------------------------------------------------------------------
-- Desire front-door
--------------------------------------------------------------------------------
function Push.GetPushDesire(bot, lane)
    -- 0) quick invalid checks
    if bot:IsInvulnerable()
        or (not bot:IsHero())
        or (not bot:IsAlive())
        or (not string.find(bot:GetUnitName(), "hero"))
        or bot:IsIllusion()
    then
        return BOT_MODE_DESIRE_NONE
    end

    -- 1) very small cache by bot+lane for stability 
    local cacheKey  = ('PushDesire:%d:%d'):format(bot:GetPlayerID(), lane or -1)
    local cachedVar = J.Utils.GetCachedVars(cacheKey, 0.6)
    if cachedVar ~= nil then
        bot.pushDesire = cachedVar
        return cachedVar
    end

    -- 2) compute and publish
    local res = Push.GetPushDesireHelper(bot, lane)
    J.Utils.SetCachedVars(cacheKey, res)
    bot.pushDesire = res
    return res
end

--------------------------------------------------------------------------------
-- Desire core
--------------------------------------------------------------------------------
function Push.GetPushDesireHelper(bot, lane)
    -- Keep the intent: avoid pushing too early or when other team jobs override.
    if bot.laneToPush == nil then bot.laneToPush = lane end

    local nMaxDesire       = 0.82
    local nSearchRange     = 2000
    local botActiveMode    = bot:GetActiveMode()
    local nModeDesire      = bot:GetActiveModeDesire()
    local bMyLane          = bot:GetAssignedLane() == lane
    local isMidOrEarlyGame = J.IsEarlyGame() or J.IsMidGame()

    hEnemyAncient = GetAncient(GetOpposingTeam())

    -- Current, LOCAL threat picture around the bot (not reused across Think)
    local alliesHere  = J.GetAlliesNearLoc(bot:GetLocation(), 1600)
    local enemiesHere = J.GetEnemiesNearLoc(bot:GetLocation(), 1600)

    -- Sync lane selection with hard bot modes
    if botActiveMode == BOT_MODE_PUSH_TOWER_TOP then
        bot.laneToPush = LANE_TOP
    elseif botActiveMode == BOT_MODE_PUSH_TOWER_MID then
        bot.laneToPush = LANE_MID
    elseif botActiveMode == BOT_MODE_PUSH_TOWER_BOT then
        bot.laneToPush = LANE_BOT
    end

    -- Do not push too early (Turbo is faster-time environment)
    local currentTime = DotaTime()
    if GetGameMode() == 23 then
        currentTime = currentTime * 2
    end

    -- Ignore push if someone just pinged "defend" recently
    J.Utils['GameStates'] = J.Utils['GameStates'] or {}
    J.Utils['GameStates']['defendPings'] = J.Utils['GameStates']['defendPings'] or { pingedTime = GameTime() }
    if GameTime() - J.Utils['GameStates']['defendPings'].pingedTime <= 5.0 then
        return BOT_MODE_DESIRE_NONE
    end

    -- Early laneing rules & neutral objectives that override pushing
    if (not bMyLane and J.IsCore(bot) and J.IsInLaningPhase())
        or (J.IsDoingRoshan(bot) and #J.GetAlliesNearLoc(J.GetCurrentRoshanLocation(), 2800) >= 3)
        or (isMidOrEarlyGame and ((#J.GetAlliesNearLoc(J.GetTormentorLocation(GetTeam()), 1600) >= 3)
            or #J.GetAlliesNearLoc(J.GetTormentorWaitingLocation(GetTeam()), 2500) >= 3))
    then
        return BOT_MODE_DESIRE_EXTRA_LOW
    end

    -- If a team member is still very low level, hold pushes entirely
    for i = 1, #GetTeamPlayers(GetTeam()) do
        local member = GetTeamMember(i)
        if member ~= nil and member:GetLevel() < 6 then
            return BOT_MODE_DESIRE_NONE
        end
    end

    -- Human opponents → delay high-commit pushes before a certain time
    local nH, _ = J.Utils.NumHumanBotPlayersInTeam(GetOpposingTeam())
    if nH > 0 and currentTime <= StartToPushTime then
        return BOT_MODE_DESIRE_EXTRA_LOW
    end

    -- If we are actively defending, cap the max desire slightly lower
    if J.IsDefending(bot) and nModeDesire >= 0.8 then
        nMaxDesire = 0.75
    end

    -- Respect allied "attack here" human ping on a tower if it matches lane
    local human, humanPing = J.GetHumanPing()
    if human ~= nil and humanPing ~= nil and not humanPing.normal_ping and DotaTime() > 0 then
        local isPinged, pingedLane = J.IsPingCloseToValidTower(GetOpposingTeam(), humanPing, 700, 5.0)
        if isPinged and lane == pingedLane and GameTime() < humanPing.time + pingTimeDelta then
            return 0.9
        end
    end

    -- If we're off doing Tormentor far from enemy ancient, lower desire
    if hEnemyAncient then
        if J.IsDoingTormentor(bot) and GetUnitToUnitDistance(bot, hEnemyAncient) > 4000 then
            return BOT_MODE_DESIRE_EXTRA_LOW
        end
    end

    -- Team state snapshot (used for several gates below)
    local aAliveCount      = J.GetNumOfAliveHeroes(false)
    local eAliveCount      = J.GetNumOfAliveHeroes(true)
    local aAliveCoreCount  = J.GetAliveCoreCount(false)
    local eAliveCoreCount  = J.GetAliveCoreCount(true)

    local hAncient         = GetAncient(GetTeam())
    local nPushDesire      = GetPushLaneDesire(lane)
    local allyKills        = J.GetNumOfTeamTotalKills(false) + 1
    local enemyKills       = J.GetNumOfTeamTotalKills(true) + 1
    local teamKillsRatio   = allyKills / enemyKills

    -- If enemies are at our ancient and we have few allies nearby → cap desire
    local teamAncientLoc   = hAncient:GetLocation()
    local nEffAlliesNearAncient = #J.GetAlliesNearLoc(teamAncientLoc, 4500) + #J.Utils.GetAllyIdsInTpToLocation(teamAncientLoc, 4500)
    local nEnemiesAroundAncient  = J.GetEnemiesAroundLoc(teamAncientLoc, 4500)
    if nEnemiesAroundAncient > 0 and nEffAlliesNearAncient < 1 then
        nMaxDesire = 0.65
    end

    -- If outnumbered in *local* area, desire is very low (avoid feed)
    if #alliesHere < #enemiesHere and aAliveCount <= eAliveCount then
        return BOT_MODE_DESIRE_VERYLOW
    end

    -- If critical items/spells are cooling down near the push location → be cautious
    local vEnemyLaneFrontLocation = GetLaneFrontLocation(GetOpposingTeam(), lane, 0)
    local waitForSpells = Push.ShouldWaitForImportantItemsSpells(vEnemyLaneFrontLocation)
    if waitForSpells and eAliveCount >= aAliveCount and eAliveCoreCount >= aAliveCoreCount then
        nMaxDesire = math.min(nMaxDesire, 0.5)
    end

    -- If already targeting a building that is backdoored, kill desire immediately
    local botTarget = bot:GetAttackTarget()
    if J.IsValidBuilding(botTarget)
        and (not string.find(botTarget:GetUnitName(), 'tower1'))
        and (not string.find(botTarget:GetUnitName(), 'tower2'))
    then
        if Push.HasBackdoorProtect(botTarget) then
            return BOT_MODE_DESIRE_EXTRA_LOW
        end
    end

    -- If close to enemy Ancient and it is hittable, prioritize it proportionally to HP
    if hEnemyAncient
        and GetUnitToUnitDistance(bot, hEnemyAncient) < (nSearchRange * 0.8)
        and J.CanBeAttacked(hEnemyAncient)
        and (not bot:WasRecentlyDamagedByAnyHero(1))
        and J.GetHP(bot) > 0.5
        and (not Push.HasBackdoorProtect(hEnemyAncient))
    then
        bot:SetTarget(hEnemyAncient)
        bot:Action_AttackUnit(hEnemyAncient, true)
        return RemapValClamped(J.GetHP(bot), 0, 0.5, BOT_MODE_DESIRE_NONE, 0.98)
    end

    -- Decide which lane to push; consider mid early, ally proximity, etc.
    local pushLane = Push.WhichLaneToPush(bot, lane)
    local isCurrentLanePushLane = pushLane == lane

    -- non-cores join the chosen lane; cores prefer chosen lane late, but can push earlier.
    if (not J.IsCore(bot) and isCurrentLanePushLane)
        or (J.IsCore(bot) and ((J.IsLateGame() and isCurrentLanePushLane) or isMidOrEarlyGame))
    then
        local allowNumbers =
                (eAliveCount == 0)
            or  (aAliveCoreCount >= eAliveCoreCount)
            or  (aAliveCoreCount >= 1 and aAliveCount >= eAliveCount + 2)

        if allowNumbers then
            if J.DoesTeamHaveAegis() then
                nPushDesire = nPushDesire + 0.3
            end

            if aAliveCount >= eAliveCount and J.GetAverageLevel(GetTeam()) >= 12 then
                local teamNetworth, enemyNetworth = J.GetInventoryNetworth()
                nPushDesire = nPushDesire + RemapValClamped(teamNetworth - enemyNetworth, 5000, 15000, 0.0, 1.0)
            end

            return RemapValClamped(nPushDesire * J.GetHP(bot), 0, 1, 0, nMaxDesire)
        end
    end

    -- Default: prefer mid as the soft fallback
    return lane == LANE_MID and BOT_MODE_DESIRE_VERYLOW or BOT_MODE_DESIRE_EXTRA_LOW
end

--------------------------------------------------------------------------------
-- Lane selection helpers
--------------------------------------------------------------------------------

-- Ally presence should make a lane cheaper (more attractive)
local function presence_adjust(score, loc)
    local allies = #J.GetAlliesNearLoc(loc, 1600)
    -- pull toward lanes with allies; 0.25 is mild and safe
    return score / (1 + 0.25 * allies)
end

local function UnitIsValidObjective(u)
    return u and J.IsValidBuilding(u) and J.CanBeAttacked(u) and (not Push.HasBackdoorProtect(u))
end

local function UnitIsBarracks(u)
    local n = u and u:GetUnitName() or ""
    return string.find(n, "barracks") ~= nil
end
local function UnitIsMeleeBarracks(u)  return UnitIsBarracks(u) and string.find(u:GetUnitName(), "melee")  ~= nil end
local function UnitIsRangedBarracks(u) return UnitIsBarracks(u) and string.find(u:GetUnitName(), "ranged") ~= nil end
local function UnitIsT3(u)
    return u == GetTower(GetOpposingTeam(), TOWER_TOP_3)
        or u == GetTower(GetOpposingTeam(), TOWER_MID_3)
        or u == GetTower(GetOpposingTeam(), TOWER_BOT_3)
end
local function UnitIsT4(u)
    return u == GetTower(GetOpposingTeam(), TOWER_BASE_1)
        or u == GetTower(GetOpposingTeam(), TOWER_BASE_2)
end
local function UnitIsFiller(u)
    -- Fillers/other inner-base buildings, exclude barracks/towers
    return J.IsValidBuilding(u) and (not UnitIsBarracks(u)) and (not UnitIsT3(u)) and (not UnitIsT4(u))
end

-- Compute a score for an objective; lower is better.
-- Base priority + mild distance terms; prefer closer to the bot and to approach targetLoc.
local function ObjectiveScore(bot, u, targetLoc)
    if not UnitIsValidObjective(u) then return math.huge end

    local base =
        (UnitIsMeleeBarracks(u)  and SCORE_BARRACKS_MELEE)
        or (UnitIsRangedBarracks(u) and SCORE_BARRACKS_RANGED)
        or (UnitIsT3(u)             and SCORE_T3)
        or (UnitIsFiller(u)         and SCORE_FILLER)
        or (UnitIsT4(u)             and SCORE_T4)
        or 2.0 -- anything unknown → worst

    local dBot = GetUnitToUnitDistance(bot, u)
    if dBot > OBJECTIVE_LEASH_RANGE then return math.huge end

    -- Distance nudges (kept light so priority dominates)
    local d1 = dBot / 2000.0             -- 0 .. ~1.3
    local d2 = targetLoc and (GetUnitToLocationDistance(u, targetLoc) / 2500.0) or 0

    return base + 0.35 * d1 + 0.20 * d2
end

-- Decide whether to keep current target or switch to a better one
local function SelectOrStickHGTarget(bot, lane, targetLoc)
    local pid = bot:GetPlayerID()
    ObjectiveState[pid] = ObjectiveState[pid] or {}
    ObjectiveState[pid][lane] = ObjectiveState[pid][lane] or {}

    local state        = ObjectiveState[pid][lane]
    local now          = GameTime()
    local current      = state.target
    local currentScore = current and ObjectiveScore(bot, current, targetLoc) or math.huge

    -- Respect stickiness if current is valid
    if current and UnitIsValidObjective(current) and now < (state.lockUntil or 0) then
        return current
    end

    -- Scan candidates
    local best, bestScore = nil, math.huge
    for _, b in pairs(GetUnitList(UNIT_LIST_ENEMY_BUILDINGS)) do
        local sc = ObjectiveScore(bot, b, targetLoc)
        if sc < bestScore then
            best, bestScore = b, sc
        end
    end

    -- Only switch if clearly better
    if current and UnitIsValidObjective(current) then
        if best and (bestScore + SWITCH_SCORE_MARGIN < currentScore) then
            state.target    = best
            state.lockUntil = now + OBJECTIVE_STICKY_TIME
            return best
        else
            state.lockUntil = now + 0.6
            return current
        end
    end

    -- Adopt best if nothing valid
    if best then
        state.target    = best
        state.lockUntil = now + OBJECTIVE_STICKY_TIME
        return best
    end

    state.target, state.lockUntil = nil, nil
    return nil
end

function Push.WhichLaneToPush(bot, lane)
    -- Score smaller = better
    local topLaneScore, midLaneScore, botLaneScore = 0, 0, 0

    local vTop = GetLaneFrontLocation(GetTeam(), LANE_TOP, 0)
    local vMid = GetLaneFrontLocation(GetTeam(), LANE_MID, 0)
    local vBot = GetLaneFrontLocation(GetTeam(), LANE_BOT, 0)

    -- Prefer lanes closer to humans/cores; de-prioritize supports’ solo pushes
    for i = 1, #GetTeamPlayers(GetTeam()) do
        local member = GetTeamMember(i)
        if J.IsValidHero(member) then
            local topDist = GetUnitToLocationDistance(member, vTop)
            local midDist = GetUnitToLocationDistance(member, vMid)
            local botDist = GetUnitToLocationDistance(member, vBot)

            if J.IsCore(member) and not member:IsBot() then
                topDist, midDist, botDist = topDist * 0.2, midDist * 0.2, botDist * 0.2
            elseif not J.IsCore(member) then
                topDist, midDist, botDist = topDist * 1.5, midDist * 1.5, botDist * 1.5
            end

            topLaneScore = topLaneScore + topDist
            midLaneScore = midLaneScore + midDist
            botLaneScore = botLaneScore + botDist
        end
    end

    -- Enemy last seen / incoming TPs near their lane fronts → inflate that lane score
    local countTop, countMid, countBot = 0, 0, 0
    for _, id in pairs(GetTeamPlayers(GetOpposingTeam())) do
        if IsHeroAlive(id) then
            local info = GetHeroLastSeenInfo(id)
            if info ~= nil then
                local dInfo = info[1]
                if dInfo ~= nil then
                    if     J.GetDistance(vTop, dInfo.location) <= 1600 then countTop = countTop + 1
                    elseif J.GetDistance(vMid, dInfo.location) <= 1600 then countMid = countMid + 1
                    elseif J.GetDistance(vBot, dInfo.location) <= 1600 then countBot = countBot + 1
                    end
                end
            end
        end
    end

    local hTeleports = GetIncomingTeleports()
    for _, tp in pairs(hTeleports) do
        if tp ~= nil and Push.IsEnemyTP(tp.playerid) then
            if     J.GetDistance(vTop, tp.location) <= 1600 then countTop = countTop + 1
            elseif J.GetDistance(vMid, tp.location) <= 1600 then countMid = countMid + 1
            elseif J.GetDistance(vBot, tp.location) <= 1600 then countBot = countBot + 1
            end
        end
    end

    topLaneScore = topLaneScore * (0.05 * countTop + 1)
    midLaneScore = midLaneScore * (0.05 * countMid + 1)
    botLaneScore = botLaneScore * (0.05 * countBot + 1)

    -- Prefer lanes with lower-tier outer buildings first. Start mid slightly.
    local topTier = Push.GetLaneBuildingTier(LANE_TOP)
    local midTier = Push.GetLaneBuildingTier(LANE_MID)
    local botTier = Push.GetLaneBuildingTier(LANE_BOT)

    if midTier < topTier and midTier < botTier then
        midLaneScore = midLaneScore * 0.5
        if not J.Utils.IsAnyBarracksOnLaneAlive(false, LANE_MID) then midLaneScore = midLaneScore * 0.5 end
    elseif topTier < midTier and topTier < botTier then
        topLaneScore = topLaneScore * 0.5
        if not J.Utils.IsAnyBarracksOnLaneAlive(false, LANE_TOP) then topLaneScore = topLaneScore * 0.5 end
    elseif botTier < topTier and botTier < midTier then
        botLaneScore = botLaneScore * 0.5
        if not J.Utils.IsAnyBarracksOnLaneAlive(false, LANE_BOT) then botLaneScore = botLaneScore * 0.5 end
    end

    -- Pull toward lanes where allies already are
    topLaneScore = presence_adjust(topLaneScore, vTop)
    midLaneScore = presence_adjust(midLaneScore, vMid)
    botLaneScore = presence_adjust(botLaneScore, vBot)

    if  topLaneScore < midLaneScore and topLaneScore < botLaneScore then return LANE_TOP end
    if  midLaneScore < topLaneScore and midLaneScore < botLaneScore then return LANE_MID end
    if  botLaneScore < topLaneScore and botLaneScore < midLaneScore then return LANE_BOT end

    return LANE_MID
end

--------------------------------------------------------------------------------
-- Think loop
--------------------------------------------------------------------------------

local fNextMovementTime = 0

function Push.PushThink(bot, lane)
    -- 0) baseline action gates
    if J.CanNotUseAction(bot) then return end
    if J.Utils.IsBotThinkingMeaningfulAction(bot, Customize.ThinkLess, "push") then return end

    -- 1) Always compute a fresh local threat picture FROM THE BOT
    local alliesHere  = J.GetAlliesNearLoc(bot:GetLocation(), 1600)
    local enemiesHere = J.GetEnemiesNearLoc(bot:GetLocation(), 1600)

    -- 2) Build a lane-front offset depending on our HP and attack range
    local botAttackRange = bot:GetAttackRange()
    local fDeltaFromFront =
        (Min(J.GetHP(bot), 0.7) * 1000 - 700) -- healthier → stand a bit closer
        + RemapValClamped(botAttackRange, 300, 700, 0, -600) -- longer range → stand further back

    -- 3) Basic tower & creep context to make hit-tower decisions safer
    local nEnemyTowers = bot:GetNearbyTowers(1200, true)
    local nAllyCreeps  = bot:GetNearbyLaneCreeps(1200, false)

    -- 4) If outnumbered locally OR our intended target near lane-front is backdoored,
    --    then pull the lane-front delta back substantially to avoid feeding.
    if (#alliesHere < #enemiesHere) or Push.IsAnyTargetBackdooredAt(bot, lane) then
        local longestRange = 0
        for _, enemyHero in pairs(enemiesHere) do
            if J.IsValidHero(enemyHero) and not J.IsSuspiciousIllusion(enemyHero) then
                local r = enemyHero:GetAttackRange()
                if r > longestRange then longestRange = r end
            end
        end
        fDeltaFromFront = -1000 - longestRange
    end

    -- 5) Compute our approach waypoint for this lane
    local targetLoc = GetLaneFrontLocation(GetTeam(), lane, fDeltaFromFront)

    -- 6) If the nearest enemy tower is shooting (or just shot) us → kite back
    if J.IsValidBuilding(nEnemyTowers[1]) and (
        nEnemyTowers[1]:GetAttackTarget() == bot
            or (nEnemyTowers[1]:GetAttackTarget() ~= bot and bot:WasRecentlyDamagedByTower(#nAllyCreeps <= 2 and 4.0 or 2.0))
    ) then
        local nDamage = nEnemyTowers[1]:GetAttackDamage() * nEnemyTowers[1]:GetAttackSpeed() * 5.0 - bot:GetHealthRegen() * 5.0
        if (bot:GetActualIncomingDamage(nDamage, DAMAGE_TYPE_PHYSICAL) / bot:GetHealth() > 0.15) or #nAllyCreeps > 2 then
            bot:Action_MoveToLocation(GetLaneFrontLocation(GetTeam(), lane, -1200))
            return
        end
    end

    -- 7) Ancient-endgame logic: if we’re in range and it’s hittable, do it
    hEnemyAncient = hEnemyAncient or GetAncient(GetOpposingTeam())
    local alliesNearAncient = hEnemyAncient and J.GetAlliesNearLoc(hEnemyAncient:GetLocation(), 1600) or {}
    if hEnemyAncient
        and GetUnitToUnitDistance(bot, hEnemyAncient) < 1600
        and J.CanBeAttacked(hEnemyAncient)
        and (not Push.HasBackdoorProtect(hEnemyAncient))
        and (#Push.GetAllyHeroesAttackingUnit(hEnemyAncient) >= 3
            or #Push.GetAllyCreepsAttackingUnit(hEnemyAncient) >= 4
            or hEnemyAncient:GetHealthRegen() < 20
            or #alliesNearAncient >= 4)
    then
        bot:Action_AttackUnit(hEnemyAncient, true)
        return
    end

    -- 8) Find attackable creeps to thin out while we approach (prefer those not under tower)
    local nRange = math.min(700 + botAttackRange, 1600)
    if hEnemyAncient and GetUnitToUnitDistance(bot, hEnemyAncient) < 2600 then
        -- bump the search radius when we’re near high ground / base
        nRange = 1600
    end

    local nCreeps = bot:GetNearbyLaneCreeps(nRange, true)
    if GetUnitToLocationDistance(bot, targetLoc) <= 1200 then
        -- if we're *already* near the approach point, include all creeps
        nCreeps = bot:GetNearbyCreeps(nRange, true)
    end
    nCreeps = Push.GetSpecialUnitsNearby(bot, nCreeps, nRange)

    local vTeamFountain = J.GetTeamFountain()
    local bTowerNearby  = J.IsValidBuilding(nEnemyTowers[1]) -- only consider creeps "in front" of tower
    for _, creep in pairs(nCreeps) do
        if J.IsValid(creep)
            and J.CanBeAttacked(creep)
            and (not bTowerNearby
                or (bTowerNearby and GetUnitToLocationDistance(creep, vTeamFountain) < GetUnitToLocationDistance(nEnemyTowers[1], vTeamFountain)))
            and not J.IsTormentor(creep)
            and not J.IsRoshan(creep)
        then
            bot:Action_AttackUnit(creep, true)
            return
        end
    end

    -- 9) High-ground building priorities: barracks → towers → fillers
    -- Unified high-ground objective selection with stickiness (prevents thrash)
    local hgTarget = SelectOrStickHGTarget(bot, lane, targetLoc)
    if hgTarget then
        if J.IsInRange(bot, hgTarget, botAttackRange + 150) then
            bot:Action_AttackUnit(hgTarget, true)
        else
            bot:Action_MoveToLocation(hgTarget:GetLocation())
        end
        return
    end

    -- 10) Movement fallback: path to approach point, then do small attack-move jitter to hold space
    if GetUnitToLocationDistance(bot, targetLoc) > 500 then
        bot:Action_MoveToLocation(targetLoc)
        return
    else
        if DotaTime() >= fNextMovementTime then
            bot:Action_AttackMove(J.GetRandomLocationWithinDist(targetLoc, 0, 400))
            fNextMovementTime = DotaTime() + RandomFloat(0.05, 0.3)
            return
        end
    end
end

--------------------------------------------------------------------------------
-- High-ground cross-lane clearing
--------------------------------------------------------------------------------
function TryClearingOtherLaneHighGround(bot, vLocation)
    local unitList = GetUnitList(UNIT_LIST_ENEMY_BUILDINGS)

    local function IsValid(building)
        return J.IsValidBuilding(building)
            and J.CanBeAttacked(building)
            and (not Push.HasBackdoorProtect(building))
    end

    -- Prefer closest barracks first
    local hBarrackTarget, best = nil, math.huge
    for _, barrack in pairs(unitList) do
        if IsValid(barrack) and (
               barrack == GetBarracks(GetOpposingTeam(), BARRACKS_TOP_MELEE)
            or barrack == GetBarracks(GetOpposingTeam(), BARRACKS_TOP_RANGED)
            or barrack == GetBarracks(GetOpposingTeam(), BARRACKS_MID_MELEE)
            or barrack == GetBarracks(GetOpposingTeam(), BARRACKS_MID_RANGED)
            or barrack == GetBarracks(GetOpposingTeam(), BARRACKS_BOT_MELEE)
            or barrack == GetBarracks(GetOpposingTeam(), BARRACKS_BOT_RANGED)
        ) then
            local d = GetUnitToLocationDistance(barrack, vLocation)
            if d < best then
                hBarrackTarget, best = barrack, d
            end
        end
    end
    if hBarrackTarget then return hBarrackTarget end

    -- Then closest T3 tower
    local hTowerTarget, best = nil, math.huge
    for _, tower in pairs(unitList) do
        if IsValid(tower) and (
               tower == GetTower(GetOpposingTeam(), TOWER_TOP_3)
            or tower == GetTower(GetOpposingTeam(), TOWER_MID_3)
            or tower == GetTower(GetOpposingTeam(), TOWER_BOT_3)
        ) then
            local d = GetUnitToLocationDistance(tower, vLocation)
            if d < best then
                hTowerTarget, best = tower, d
            end
        end
    end
    if hTowerTarget then return hTowerTarget end
end

--------------------------------------------------------------------------------
-- Utility helpers (validation, backdoor checks, etc.)
--------------------------------------------------------------------------------

function Push.CanBeAttacked(building)
    return building ~= nil
        and building:CanBeSeen()
        and (not building:IsInvulnerable())
end

function Push.IsEnemyTP(nID)
    for _, id in pairs(GetTeamPlayers(GetOpposingTeam())) do
        if id == nID then return true end
    end
    return false
end

-- Estimate if staying in a tower’s zone is too dangerous over fDuration seconds
function Push.IsInDangerWithinTower(hUnit, fThreshold, fDuration)
    local totalDamage = 0
    for _, enemy in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
        if J.IsValid(enemy)
            and J.IsInRange(hUnit, enemy, 1600)
            and (enemy:GetAttackTarget() == hUnit or J.IsChasingTarget(enemy, hUnit))
        then
            totalDamage = totalDamage + hUnit:GetActualIncomingDamage(
                enemy:GetAttackDamage() * enemy:GetAttackSpeed() * fDuration,
                DAMAGE_TYPE_PHYSICAL
            )
        end
    end

    return (totalDamage / hUnit:GetHealth() * 1.2) > fThreshold
end

-- Include micro-summons & dominated units into "nearby creeps" for push thinning
function Push.GetSpecialUnitsNearby(bot, hUnitList, nRadius)
    local hCreepList = {}
    -- copy first (avoid mutating original table)
    for i = 1, #hUnitList do hCreepList[i] = hUnitList[i] end

    for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
        if unit ~= nil and unit:CanBeSeen() and J.IsInRange(bot, unit, nRadius) then
            local s = unit:GetUnitName()
            if string.find(s, 'invoker_forge_spirit')
                or string.find(s, 'lycan_wolf')
                or string.find(s, 'eidolon')
                or string.find(s, 'beastmaster_boar')
                or string.find(s, 'beastmaster_greater_boar')
                or string.find(s, 'furion_treant')
                or string.find(s, 'broodmother_spiderling')
                or string.find(s, 'skeleton_warrior')
                or string.find(s, 'warlock_golem')
                or unit:HasModifier('modifier_dominated')
                or unit:HasModifier('modifier_chen_holy_persuasion')
            then
                table.insert(hCreepList, unit)
            end
        end
    end

    return hCreepList
end

function Push.IsHealthyInsideFountain(hUnit)
    return hUnit:HasModifier('modifier_fountain_aura_buff')
        and J.GetHP(hUnit) > 0.90
        and J.GetMP(hUnit) > 0.85
end

function Push.GetAllyHeroesAttackingUnit(hUnit)
    local out = {}
    for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
        if J.IsValidHero(ally)
            and (not J.IsSuspiciousIllusion(ally))
            and (not J.IsMeepoClone(ally))
            and ally:GetAttackTarget() == hUnit
        then
            table.insert(out, ally)
        end
    end
    return out
end

function Push.GetAllyCreepsAttackingUnit(hUnit)
    local out = {}
    for _, creep in pairs(GetUnitList(UNIT_LIST_ALLIED_CREEPS)) do
        if J.IsValid(creep) and creep:GetAttackTarget() == hUnit then
            table.insert(out, creep)
        end
    end
    return out
end

-- Returns 1..4 for the highest structure on that lane that is still alive on the enemy team
function Push.GetLaneBuildingTier(nLane)
    if nLane == LANE_TOP then
        if GetTower(GetOpposingTeam(), TOWER_TOP_1) ~= nil then return 1
        elseif GetTower(GetOpposingTeam(), TOWER_TOP_2) ~= nil then return 2
        elseif GetTower(GetOpposingTeam(), TOWER_TOP_3) ~= nil
            or GetBarracks(GetOpposingTeam(), BARRACKS_TOP_MELEE) ~= nil
            or GetBarracks(GetOpposingTeam(), BARRACKS_TOP_RANGED) ~= nil
        then return 3
        else return 4 end
    elseif nLane == LANE_MID then
        if GetTower(GetOpposingTeam(), TOWER_MID_1) ~= nil then return 1
        elseif GetTower(GetOpposingTeam(), TOWER_MID_2) ~= nil then return 2
        elseif GetTower(GetOpposingTeam(), TOWER_MID_3) ~= nil
            or GetBarracks(GetOpposingTeam(), BARRACKS_MID_MELEE) ~= nil
            or GetBarracks(GetOpposingTeam(), BARRACKS_MID_RANGED) ~= nil
        then return 3
        else return 4 end
    elseif nLane == LANE_BOT then
        if GetTower(GetOpposingTeam(), TOWER_BOT_1) ~= nil then return 1
        elseif GetTower(GetOpposingTeam(), TOWER_BOT_2) ~= nil then return 2
        elseif GetTower(GetOpposingTeam(), TOWER_BOT_3) ~= nil
            or GetBarracks(GetOpposingTeam(), BARRACKS_BOT_MELEE) ~= nil
            or GetBarracks(GetOpposingTeam(), BARRACKS_BOT_RANGED) ~= nil
        then return 3
        else return 4 end
    end
    return 1
end

function Push.ShouldWaitForImportantItemsSpells(vLocation)
    if J.IsMidGame() or J.IsLateGame() then
        if J.Utils.HasTeamMemberWithCriticalItemInCooldown(vLocation) then return true end
        if J.Utils.HasTeamMemberWithCriticalSpellInCooldown(vLocation) then return true end
    end
    return false
end

function Push.HasBackdoorProtect(target)
    return target:HasModifier('modifier_fountain_glyph')
        or target:HasModifier('modifier_backdoor_protection')
        or target:HasModifier('modifier_backdoor_protection_in_base')
        or target:HasModifier('modifier_backdoor_protection_active')
end

--------------------------------------------------------------------------------
-- New targeted helpers to reduce thrash/jitter
--------------------------------------------------------------------------------

-- Returns true if the *nearest* intended target around the enemy lane-front
-- is currently backdoored/glyphed.
function Push.IsAnyTargetBackdooredAt(bot, lane)
    local lf = GetLaneFrontLocation(GetTeam(), lane, 0)
    local nearest, best = nil, math.huge
    for _, b in pairs(GetUnitList(UNIT_LIST_ENEMY_BUILDINGS)) do
        if J.IsValidBuilding(b) then
            local d = GetUnitToLocationDistance(b, lf)
            if d < best then nearest, best = b, d end
        end
    end
    return nearest and Push.HasBackdoorProtect(nearest) or false
end

-- Picks best high-ground objective with strict priority:
--   1) Barracks: melee > ranged (closest of each class)
--   2) Tier-3 towers (closest)
--   3) Fillers/others (closest)
-- Radius is the max distance from the bot; tie-breaker favors closer to targetLoc.
function Push.FindBestHGTarget(bot, radius, targetLoc)
    local function isBarracks(u)
        local n = u:GetUnitName()
        return n and string.find(n, "barracks")
    end
    local function isMeleeBarracks(u)
        local n = u:GetUnitName()
        return n and string.find(n, "melee")
    end
    local function isRangedBarracks(u)
        local n = u:GetUnitName()
        return n and string.find(n, "ranged")
    end
    local function isT3Tower(u)
        return u == GetTower(GetOpposingTeam(), TOWER_TOP_3)
            or u == GetTower(GetOpposingTeam(), TOWER_MID_3)
            or u == GetTower(GetOpposingTeam(), TOWER_BOT_3)
    end

    local bestMelee, bestMeleeD = nil, math.huge
    local bestRanged, bestRangedD = nil, math.huge
    local bestT3, bestT3D = nil, math.huge
    local bestOther, bestOtherD = nil, math.huge

    for _, b in pairs(GetUnitList(UNIT_LIST_ENEMY_BUILDINGS)) do
        if J.IsValidBuilding(b) and J.CanBeAttacked(b) and (not Push.HasBackdoorProtect(b)) then
            local dBot = GetUnitToUnitDistance(bot, b)
            if dBot <= radius then
                -- prefer closer to our approach point when bot-distance is similar
                local dLoc = targetLoc and GetUnitToLocationDistance(b, targetLoc) or 0

                if isBarracks(b) then
                    if isMeleeBarracks(b) then
                        if dBot < bestMeleeD or (dBot == bestMeleeD and dLoc < GetUnitToLocationDistance(bestMelee or b, targetLoc)) then
                            bestMelee, bestMeleeD = b, dBot
                        end
                    elseif isRangedBarracks(b) then
                        if dBot < bestRangedD or (dBot == bestRangedD and dLoc < GetUnitToLocationDistance(bestRanged or b, targetLoc)) then
                            bestRanged, bestRangedD = b, dBot
                        end
                    end
                elseif isT3Tower(b) then
                    if dBot < bestT3D or (dBot == bestT3D and dLoc < GetUnitToLocationDistance(bestT3 or b, targetLoc)) then
                        bestT3, bestT3D = b, dBot
                    end
                else
                    if dBot < bestOtherD or (dBot == bestOtherD and dLoc < GetUnitToLocationDistance(bestOther or b, targetLoc)) then
                        bestOther, bestOtherD = b, dBot
                    end
                end
            end
        end
    end

    return bestMelee or bestRanged or bestT3 or bestOther
end

return Push
