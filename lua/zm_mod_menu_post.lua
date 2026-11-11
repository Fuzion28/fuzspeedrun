-- Draws zm_mod_menu (GSC) with native LUI text. The GSC writes the open page into the zmm_view
-- dvar and this script redraws it: GSC HUD text (settext) showed new lines late.
-- View: ZMM|theme|right|title|cursor|rows|position|row1|...|END, each row = marker + label
-- (">" submenu, "+" toggle on, "-" toggle off, anything else plain).
local C=rawget(_G,"CLUA")
local H=rawget(_G,"xhash") or rawget(_G,"PushXHash") or (type(C)=="table" and C.PushXHash)
local HD=rawget(_G,"xhashdvar") or rawget(_G,"PushXHashDvar") or (type(C)=="table" and C.PushXHashDvar)
if type(H)~="function" or type(HD)~="function" then return end
local function cachedHash(native)
    local cache={}
    return function(name)
        local value=cache[name]
        if value==nil then value=native(name);cache[name]=value end
        return value
    end
end
H,HD=cachedHash(H),cachedHash(HD)
local old=rawget(_G,"ZmmMenuView")
if old then old.enabled=false;if old.clear then pcall(old.clear) end end
local S={enabled=true,ticks=0}
rawset(_G,"ZmmMenuView",S)

-- sizes match the PNGs from make_images.py (cap 440x16, pill 428x34)
local W,ROW,VIS,CAP,PAD=440,34,12,16,6
local ROWS_TOP=78
local THEMES={0x0099ff,0xff3333,0x33ff59,0xb34dff,0xff9900,0xffd933}
local PANEL,TEXT,DIM,INK,PILL=0x111214,0xa8acb3,0x6b6f76,0x111214,0xf2f3f5
-- main page labels (FR and EN) -> Assets/Images/fuzmenu_i_<icon>.png
local ICONS={["Joueur"]="player",["Player"]="player",["OP Mode"]="op",["Teleports"]="teleport",
    ["Armes"]="gun",["Weapons"]="gun",["Co-op"]="player",["Desactiver tous les mods"]="close",["Disable all mods"]="close",["Donner une arme"]="gun",["Give a weapon"]="gun",["Armes miracles"]="wonder",["Wonder weapons"]="wonder",
    ["Options de tir"]="fire",["Shooting options"]="fire",["Degats"]="damage",["Damage"]="damage",
    ["Ameliorer"]="upgrade",["Upgrade"]="upgrade",["Atouts"]="perks",["Perks"]="perks",["Gobblegums"]="gums",
    ["Points & scrap"]="money",["Zombies"]="zombies",["Manches"]="rounds",["Rounds"]="rounds",["Bonus"]="powerups",
    ["Speedrun"]="rounds",["Monde"]="world",["World"]="world",["Forge"]="forge",["Old School Zombies"]="oldschool",
    ["Parametres"]="settings",["Settings"]="settings",["Fermer"]="close",["Close"]="close"}

local function plainIndex(object,key) return object[key] end
local function hashedIndex(object,key) return object[H(key)] end
local function get(object,key)
    if object==nil then return nil end
    local plain,value=pcall(plainIndex,object,key)
    if plain and value~=nil then return value end
    local ok,hashed=pcall(hashedIndex,object,key)
    if ok then return hashed end
    return nil
end
local function invoke(object,key,...)
    local f=get(object,key)
    if type(f)=="function" then return f(...) end
end
local function call(object,key,...)
    local f=get(object,key)
    if type(f)=="function" then return f(object,...) end
end
local function read(name)
    local value=invoke(rawget(_G,"Dvar"),"GetDvarString",HD(name))
    if value~=nil then return tostring(value) end
end
local function inMatch()
    return invoke(rawget(_G,"Engine"),"InFrontend")==false
end

local function newElement(kind)
    local f=get(get(rawget(_G,"LUI"),kind),"new")
    if type(f)~="function" then error("Native "..kind.." constructor unavailable",0) end
    return f()
end
local function passive(element)
    call(element,"SetHandleMouse",false);call(element,"setFocusable",false)
end
local function place(node,x,y,w,h,duration)
    if duration and duration>0 and type(get(node,"SetTop"))=="function" then
        local easing=get(get(rawget(_G,"LUI"),"EASING"),"outQuadratic")
        call(node,"SetTop",y,duration,easing);call(node,"SetBottom",y+h,duration,easing)
    else
        call(node,"SetAnchorsAndPosition",0,1,0,1,x,x+w,y,y+h)
    end
end
local function rectangle(parent,x,y,w,h,rgb,alpha)
    local element=newElement("UIImage")
    place(element,x,y,w,h)
    call(element,"SetRGB",rgb);call(element,"SetAlpha",alpha)
    passive(element);call(parent,"addElement",element)
    return element
end
local function label(parent,x,y,w,h,size,rgb,bold)
    local element=newElement("UIStyledText")
    place(element,x,y,w,h)
    local fonts=rawget(_G,"FONT_HANDLE")
    local font=(bold and get(fonts,"PrimaryBold")) or get(fonts,"TertiaryMedium") or get(fonts,"SecondaryRegular") or get(fonts,"PrimaryBold") or get(fonts,"PrimaryRegular")
    if font then call(element,"SetFont",font) end
    call(element,"SetFontSize",size*(tonumber(rawget(_G,"_PT")) or 1))
    call(element,"SetRGB",rgb);call(element,"SetAlignment",0)
    passive(element);call(parent,"addElement",element)
    return element
end

-- PNG from kronos/Assets/Images (made by make_images.py), loaded like Project Nexus loads its art
local function material(name)
    S.materials=S.materials or {}
    if S.materials[name]==nil then
        local register=rawget(_G,"RegisterMaterial")
        local asset=rawget(_G,"xhashasset") or get(C,"PushXHashAsset")
        local ok,value=false,nil
        if type(register)=="function" then
            ok,value=pcall(function()return register(type(asset)=="function" and asset(name) or name)end)
        end
        S.materials[name]=ok and value or false
    end
    return S.materials[name] or nil
end
-- white PNG tinted rgb; a plain rectangle when the picture is missing
local function picture(parent,name,x,y,w,h,rgb,alpha)
    local element=rectangle(parent,x,y,w,h,rgb,alpha)
    local mat=material(name)
    if mat then call(element,"setImage",mat) end
    return element
end

local function clear()
    if S.frame then pcall(call,S.frame,"closeTree") end
    S.frame=nil;S.parent=nil;S.last=nil;S.visible=false
end
local function hide()
    if S.frame and S.visible then call(S.frame,"SetAlpha",0,0) end
    S.visible=false;S.last=nil
end
local function parentFor(root)
    if type(get(root,"addElement"))~="function" then return nil end
    for _=1,16 do
        local parent=call(root,"getParent")
        if not parent or parent==root then break end
        root=parent
    end
    return root
end
local function displayParent()
    return parentFor(invoke(get(rawget(_G,"LUI"),"UIRoot"),"GetRootForControllerIndex",0))
end

local function build(parent)
    clear()
    local frame=newElement("UIElement")
    call(frame,"SetAlpha",0);call(frame,"setPriority",1000);passive(frame);call(parent,"addElement",frame)
    S.frame=frame;S.parent=parent
    -- rounded panel: top cap, stretched body, bottom cap
    S.capTop=picture(frame,"fuzmenu_cap_t",0,0,W,CAP,PANEL,.96)
    S.body=rectangle(frame,0,CAP,W,10,PANEL,.96)
    S.capBottom=picture(frame,"fuzmenu_cap_b",0,0,W,CAP,PANEL,.96)
    S.brand=label(frame,20,14,200,16,13,THEMES[1])
    call(S.brand,"setText","FuzSpeedrun")
    S.count=label(frame,W-80,14,64,16,13,DIM)
    S.title=label(frame,20,32,W-40,30,26,0xffffff,true)
    S.pill=picture(frame,"fuzmenu_pill",PAD,ROWS_TOP,W-2*PAD,ROW,PILL,1)
    S.rows={};S.icons={};S.chevs={};S.tracks={};S.knobs={}
    for i=1,VIS do
        local y=ROWS_TOP+(i-1)*ROW
        S.icons[i]=rectangle(frame,20,y+8,18,18,TEXT,0)
        S.rows[i]=label(frame,48,y+6,W-130,ROW-10,18,TEXT)
        S.chevs[i]=picture(frame,"fuzmenu_i_chevron",W-34,y+10,14,14,DIM,0)
        S.tracks[i]=picture(frame,"fuzmenu_switch",W-52,y+9,30,16,DIM,0)
        S.knobs[i]=picture(frame,"fuzmenu_knob",W-50,y+11,12,12,0xffffff,0)
    end
    -- scroll position bar
    S.track=rectangle(frame,20,0,W-40,3,0x26282c,1)
    S.fill=rectangle(frame,20,0,3,3,THEMES[1],1)
    S.footer=label(frame,20,0,W-40,18,13,DIM)
    S.footer2=label(frame,20,0,W-40,18,13,DIM)
    S.pad=nil
end

-- weapon refs (sat_lm_typhon) become the game's localized name, as ProjectNexus does
local names={}
local function weaponName(ref)
    if not ref:match("^sat_[a-z]+_[a-z0-9]+$") then return ref end
    if names[ref] then return names[ref] end
    local name=ref:match("^sat_[a-z]+_(.+)$")
    local ok,raw=pcall(invoke,rawget(_G,"WEAPON"),"GetName",ref)
    if ok and raw~=nil then
        local okL,value=pcall(invoke,rawget(_G,"Engine"),"Localize",raw)
        if okL and type(value)=="string" and value~="" and value~=ref and not value:match("^#x") then name=value
        elseif type(raw)=="string" and raw~="" and raw~=ref and not raw:match("^#x") then name=raw end
    end
    names[ref]=name;return name
end

-- shortcut: controller labels assume the default layout (Xbox names), upgrade if the game exposes the player's binds to Lua
local FOOTERS={
    ["0"]={"Arrows / RMB-LMB: Move    Enter / F: OK","Backspace / V: Back    Insert: Open"},
    ["1"]={"D-pad / LT-RT: Move    X (PS: Square): OK","R3: Back    LT + R3: Open"},
}

local function parse(text)
    if type(text)~="string" or #text>4096 then return nil end
    local f={};for field in (text.."|"):gmatch("(.-)|") do f[#f+1]=field end
    local n=tonumber(f[6])
    if f[1]~="ZMM" or not n or n<1 or n>VIS or #f~=n+8 or f[#f]~="END" then return nil end
    return f,n
end

local function render(f,n)
    local theme=THEMES[(tonumber(f[2]) or 0)+1] or THEMES[1]
    local cursor=math.max(0,math.min(n-1,tonumber(f[5]) or 0))
    local fy=ROWS_TOP+n*ROW+10
    local h=fy+62
    -- top edge stays put when the page length changes
    if f[3]=="1" then call(S.frame,"SetAnchorsAndPosition",1,0,.5,.5,-W-60,-60,-330,-330+h)
    else call(S.frame,"SetAnchorsAndPosition",0,1,.5,.5,60,60+W,-330,-330+h) end
    place(S.body,0,CAP,W,h-2*CAP);place(S.capBottom,0,h-CAP,W,CAP)
    call(S.brand,"SetRGB",theme);call(S.fill,"SetRGB",theme)
    -- GSC titles are upper case ("MENU PRINCIPAL"): shown as "Menu principal"
    call(S.title,"setText",((f[4] or ""):lower():gsub("^%l",string.upper)))
    local at,total=(f[7] or ""):match("(%d+)/(%d+)")
    call(S.count,"setText",at and string.format("%02d / %02d",tonumber(at),tonumber(total)) or "")
    for i=1,VIS do
        local shown,icon,marker=i<=n,nil,nil
        if shown then
            local y=ROWS_TOP+(i-1)*ROW
            local row=f[i+7]
            marker=row:sub(1,1)
            local raw=(row:sub(2):gsub("%^%d",""))
            icon=ICONS[raw] and material("fuzmenu_i_"..ICONS[raw])
            local selected=i==cursor+1
            local text=weaponName(raw):gsub("^%l",string.upper)
            call(S.rows[i],"setText",text)
            call(S.rows[i],"SetRGB",selected and INK or 0xd8dbe0)
            place(S.rows[i],icon and 48 or 20,y+6,W-130,ROW-10)
            if icon then call(S.icons[i],"setImage",icon);call(S.icons[i],"SetRGB",selected and INK or TEXT) end
            call(S.chevs[i],"SetRGB",selected and INK or DIM)
            call(S.tracks[i],"SetRGB",marker=="+" and theme or (selected and 0xc9ccd1 or 0x3a3c41))
            place(S.knobs[i],marker=="+" and W-36 or W-50,y+11,12,12)
        end
        local toggle=shown and (marker=="+" or marker=="-")
        call(S.rows[i],"SetAlpha",shown and 1 or 0)
        call(S.icons[i],"SetAlpha",icon and 1 or 0)
        call(S.chevs[i],"SetAlpha",marker==">" and 1 or 0)
        call(S.tracks[i],"SetAlpha",toggle and 1 or 0)
        call(S.knobs[i],"SetAlpha",toggle and 1 or 0)
    end
    place(S.pill,PAD,ROWS_TOP+cursor*ROW,W-2*PAD,ROW,S.visible and 80 or 0)
    place(S.track,20,fy,W-40,3)
    place(S.fill,20,fy,math.max(3,math.floor((W-40)*(tonumber(at) or 1)/math.max(1,tonumber(total) or 1))),3)
    place(S.footer,20,fy+12,W-40,18)
    place(S.footer2,20,fy+30,W-40,18)
    if not S.visible then call(S.frame,"SetAlpha",1,120) end
    S.visible=true
end

-- native rows of the pause menu: copies of the game's own row widget, added to its list
local PR={last=0,seq=0}
local function prCall(o,k,...) local ok,v=pcall(call,o,k,...);if ok then return v end;return nil end
local function prId(e) return tostring((get(e,"id"))) end
local function prFind(e,hex,depth)
    local c=prCall(e,"getFirstChild")
    while c do
        if string.find(prId(c),hex,1,true) then return c end
        if depth<8 then local r=prFind(c,hex,depth+1);if r then return r end end
        c=prCall(c,"getNextSibling")
    end
end
local function prSet(name,value) invoke(rawget(_G,"Dvar"),"SetDvarString",HD(name),value) end
local function prToggle(title,dvar)
    return {text=function() return title..(read(dvar)=="1" and ": ON" or ": OFF") end,
        press=function() prSet(dvar,read(dvar)=="1" and "0" or "1") end}
end
local function prAction(title,action)
    return {text=function() return title end,
        press=function() PR.seq=PR.seq+1;prSet("zmm_paction",action.." "..PR.seq) end}
end
-- off > timer + splits > timer only, the BO3 Show Timer / Show Splits pair on one row
local function prTimer()
    return {text=function()
            if read("zmm_ptimer")=="0" then return "TIMER: OFF" end
            return read("zmm_pshow")=="0" and "TIMER: ON" or "TIMER + SPLITS: ON"
        end,
        press=function()
            if read("zmm_ptimer")=="0" then prSet("zmm_ptimer","1");prSet("zmm_pshow","1")
            elseif read("zmm_pshow")=="0" then prSet("zmm_ptimer","0")
            else prSet("zmm_pshow","0") end
        end}
end
-- easter egg > pack-a-punch > round 5 > ... > round 100, the speedrun.com categories
local MODES={"ee","pap","r5","r15","r30","r50","r70","r100"}
local function prMode()
    return {text=function()
            local m=read("zmm_pmode")
            if m=="pap" then return "MODE: PACK-A-PUNCH" end
            if m and m:match("^r%d+$") then return "MODE: ROUND "..m:sub(2) end
            return "MODE: EASTER EGG"
        end,
        press=function()
            local m,n=read("zmm_pmode"),1
            for i,v in ipairs(MODES) do if v==m then n=i%#MODES+1 end end
            prSet("zmm_pmode",MODES[n])
        end}
end
local function prRefresh()
    for _,row in ipairs(PR.rows) do if row.set then row.set(row.label,row.text()) end end
end
local function prAdd(list,tail,prev,row)
    local btn=rawget(_G,"MenuBuilder").BuildRegisteredType(H("0xe4df62cf810d16c2"),{controllerIndex=0})
    call(btn,"addElementBefore",tail)
    -- 22 high, not the native 51: eight rows must stay above the tokens line
    call(btn,"SetAnchorsAndPosition",0,0,0,1,0,0,0,22)
    row.label=prFind(btn,"fa04f4ef1995407e",0)
    row.set=get(row.label,"setText")
    pcall(function() row.label.setText=function() end end)
    call(btn,"addEventHandler",H("0xe7eefe998522ec88"),function()
        -- one press can reach the handler twice
        if S.ticks-PR.last<5 then return end
        PR.last=S.ticks
        row.press()
        prRefresh()
    end)
    local ebu=rawget(_G,"ElementAndButtonUtils")
    local link,dirs=get(ebu,"0x42b31d442266478c"),get(ebu,"0x75992a095c731b0c")
    pcall(link,prev,btn,get(dirs,"0xdc04126761bb7455"))
    pcall(link,btn,prev,get(dirs,"0x08c43a07b566d980"))
    return btn
end
local function prStep()
    local lui=rawget(_G,"LUI")
    if invoke(get(lui,"FlowManager"),"IsInStack",H("MPPauseMenu"))~=true then PR.list=nil;return end
    if S.ticks%15~=0 then return end
    -- only the host's GSC creates these with a value
    local timer=read("zmm_ptimer")
    if timer~="0" and timer~="1" then return end
    local root=invoke(lui,"GetRoot")
    local flow=prCall(root,"getFirstChild")
    while flow and prId(flow)~="flowManager" do flow=prCall(flow,"getNextSibling") end
    if not flow then return end
    local list=prFind(flow,"62edd5b8255fc7b6",0)
    if not list or list==PR.list then return end
    PR.list=list
    local tail,prev=nil,nil
    local c=prCall(list,"getFirstChild")
    while c do
        if string.find(prId(c),"a856229309a4d4b6",1,true) then tail=c
        elseif not tail and prCall(c,"IsVisible") then prev=c end
        c=prCall(c,"getNextSibling")
    end
    if not tail or not prev then return end
    PR.rows={prTimer(),prToggle("INFINITE GUMS","zmm_pgums"),prMode(),prAction("START SPEEDRUN","start")}
    for _,row in ipairs(PR.rows) do prev=prAdd(list,tail,prev,row) end
    prRefresh()
end
-- anti-splice watermark, bottom left: session id + attempt, faint like the BO3 mod
local function spliceStep()
    local text=inMatch() and read("zmm_splice") or ""
    if text==(S.spliceText or "") then return end
    if S.splice then pcall(call,S.splice,"closeTree");S.splice=nil end
    S.spliceText=text
    local parent=displayParent()
    if text=="" or not parent then S.spliceText=nil;return end
    S.splice=newElement("UIElement")
    call(S.splice,"setPriority",1000);passive(S.splice);call(parent,"addElement",S.splice)
    call(S.splice,"SetAnchorsAndPosition",0,1,1,0,20,520,-36,-10)
    call(label(S.splice,0,0,500,26,18,0xffffff),"setText",text)
    call(S.splice,"SetAlpha",.35)
end
local function tick()
    S.ticks=S.ticks+1
    pcall(prStep)
    pcall(spliceStep)
    -- the GSC writes dvars every 50 ms at most: a third of the rate while closed; %3==1 keeps the %30==1 zmm_lua beat below
    if not S.visible and S.ticks%3~=1 then return end
    if not inMatch() then if S.frame then clear() end;S.hud=nil;S.hudText=nil;S.big=nil;S.bigText=nil;return end
    -- tells the GSC this script runs, so it skips its own HUD
    if S.ticks%30==1 then
        local set=get(rawget(_G,"Dvar"),"SetDvarString")
        if type(set)=="function" and read("zmm_lua")~="1" then pcall(set,HD("zmm_lua"),"1") end
    end
    -- the GSC writes zmm_exec as "<command> <time>"; the first value seen is only remembered (stale from a past match)
    local exec=read("zmm_exec") or ""
    if S.exec==nil then S.exec=exec elseif exec~=S.exec then
        S.exec=exec
        local command=exec:match("^(.-) %d+$") or ""
        -- IW-engine Lua takes (command[, controller]); Treyarch Lua takes (controller, command): try both
        local engine=rawget(_G,"Engine")
        for _,name in ipairs({"Exec","ExecNow"}) do
            local run=get(engine,name)
            if exec~="" and type(run)=="function" then
                local ok=pcall(run,command)
                if not ok then ok=pcall(run,0,command) end
                if ok then break end
            end
        end
    end
    -- zombie counter / round timer line written by the GSC into zmm_hud
    local hud=read("zmm_hud") or ""
    if hud~=(S.hudText or "") then
        local parent=displayParent()
        if hud=="" then
            if S.hud then pcall(call,S.hud,"closeTree") end
            S.hud=nil;S.hudText=hud
        elseif parent then
            if not S.hud or S.hudParent~=parent then
                if S.hud then pcall(call,S.hud,"closeTree") end
                -- same structure as the menu: a prioritised container, then the text inside it
                S.hud=newElement("UIElement")
                call(S.hud,"setPriority",1000);passive(S.hud);call(parent,"addElement",S.hud)
                call(S.hud,"SetAnchorsAndPosition",.5,.5,0,1,-250,250,115,145)
                S.hudLabel=label(S.hud,0,0,500,26,20,0xffffff)
                call(S.hud,"SetAlpha",1)
                S.hudParent=parent
            end
            call(S.hudLabel,"setText",hud)
            S.hudText=hud
        end
    end
    -- large centred notice written by the GSC into zmm_big (boss wait)
    local big=read("zmm_big") or ""
    if big~=(S.bigText or "") then
        if S.big then pcall(call,S.big,"closeTree") end
        S.big=nil
        local parent=displayParent()
        if big=="" then S.bigText=big
        elseif parent then
            S.big=newElement("UIElement")
            call(S.big,"setPriority",1000);passive(S.big);call(parent,"addElement",S.big)
            call(S.big,"SetAnchorsAndPosition",.5,.5,.5,.5,-450,450,-140,-80)
            call(label(S.big,0,0,900,60,48,0xffd200),"setText",big)
            call(S.big,"SetAlpha",1);S.bigText=big
        end
    end
    local text=read("zmm_view") or ""
    if text=="" or invoke(get(rawget(_G,"LUI"),"FlowManager"),"IsInStack",H("MPPauseMenu"))==true then
        hide();return
    end
    local pad=read("zmm_pad")=="1" and "1" or "0"
    if S.footer and pad~=S.pad then
        S.pad=pad
        call(S.footer,"setText",FOOTERS[pad][1])
        call(S.footer2,"setText",FOOTERS[pad][2])
    end
    -- nothing new to draw: only look for a rebuilt UI root 4 times a second
    if text==S.last and S.ticks%15~=0 then return end
    local parent=displayParent()
    if not parent or (text==S.last and S.parent==parent) then return end
    local f,n=parse(text)
    if not f then return end
    if not S.frame or S.parent~=parent then build(parent) end
    render(f,n)
    S.last=text
end

-- native UI timer, as in ProjectNexus: a hidden element's Wait(16) re-armed after each tick
local function timerRoot()
    local L=rawget(_G,"LUI")
    local ok,current=pcall(invoke,L,"GetRoot")
    if ok and current then return current end
    return get(L,"primaryRoot")
end
local function ensureTimer()
    if not S.enabled then return end
    local root=timerRoot()
    if not root then return end
    local okParent,parent=pcall(call,S.timer,"getParent")
    if okParent and parent==root then return end
    if S.timer then pcall(call,S.timer,"closeTree") end
    S.timer=nil
    pcall(function()
        local host=newElement("UIElement")
        passive(host);call(root,"addElement",host);S.timer=host
        local function schedule()
            if not S.enabled or S.timer~=host then return end
            local animation=call(host,"Wait",16)
            if not animation then S.timer=nil;return end
            animation.onComplete=function()
                if not S.enabled or S.timer~=host then return end
                local ok=pcall(tick)
                if not ok then clear() end
                pcall(schedule)
            end
        end
        schedule()
    end)
end
S.ensureTimer=ensureTimer;S.clear=clear

-- arrow keys and D-pad move the open menu (GSC buttonpressed("uparrow") never fires): each press
-- bumps the zmm_up / zmm_down counter the GSC polls. Names and their hashes, as in Project Nexus.
local NAV={uparrow="up",arrowup="up",up="up",button_dpad_up="up",dpad_up="up",pad_up="up",dpadup="up",
    downarrow="down",arrowdown="down",down="down",button_dpad_down="down",dpad_down="down",pad_down="down",dpaddown="down",
    enter="enter",kp_enter="enter",["return"]="enter",backspace="back",ins="open",insert="open"}
-- sticks can report a plain "up"/"down" too: they keep their normal use
local STICKS={}
for _,prefix in ipairs({"apad_","apad2_","stick_","lstick_","rstick_","button_lstick_","button_rstick_"}) do
    for _,direction in ipairs({"up","down","left","right"}) do STICKS[prefix..direction]=true end
end
for _,names in ipairs({NAV,STICKS}) do
    local hashed={}
    for name,value in pairs(names) do hashed[tostring(H(name)):lower()]=value end
    for name,value in pairs(hashed) do names[name]=value end
end
local function navKey(button,key,uiBind)
    local b,k,u=tostring(button):lower(),tostring(key):lower(),tostring(uiBind):lower()
    if STICKS[b] or STICKS[k] or STICKS[u] then return nil end
    return NAV[k] or NAV[b]
end

-- the timer dies when the UI root is rebuilt (map load): input events restart it
local installed=setmetatable({},{__mode="k"})
local function install()
    local input=get(rawget(_G,"LUI"),"UIRoot")
    local original=get(input,"QueueInput")
    if type(original)~="function" or installed[input] then return end
    local wrapped=function(...)
        if S.enabled then pcall(ensureTimer) end
        local _,c,_,down,button,_,_,_,_,_,key,uiBind=...
        local nav=S.enabled and (tonumber(c) or 0)==0 and navKey(button,key,uiBind)
        -- Insert only acts while the menu is closed, every other key only while it is open
        if nav and (S.visible==true)==(nav~="open") then
            if down==true then
                local name="zmm_"..nav
                pcall(invoke,rawget(_G,"Dvar"),"SetDvarString",HD(name),tostring((tonumber(read(name)) or 0)+1))
            end
            -- Insert still reaches the game: it is also the Kronos menu key
            if nav~="open" then return true end
        end
        return original(...)
    end
    installed[input]=true
    input.QueueInput=wrapped;input[H("QueueInput")]=wrapped
end
pcall(ensureTimer)
pcall(install)
