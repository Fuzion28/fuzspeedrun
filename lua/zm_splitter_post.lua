-- In-game splitter (LiveSplit-layout): titel, kolommen +/- en Time, huidige split in blauw, grote timer,
-- segmenttimer en PB. Native LUI, geen eigen achtergrond.
-- AUTO (normaal): zm_splitter.gsc geeft de speedrun-splits van het menu door via dvars. De timer start zodra
--   je beweegt en elke map splitst vanzelf op zijn eigen stappen. PB's bewaart het menu per map.
-- PER MAP: titel, splitnamen, PB en beste segmenten staan in een eigen bestand per map:
--   zm_split_<mapnaam>_post.lua  (zie zm_split_TEMPLATE.txt). Nieuwe map = nieuw bestand erbij, dit bestand
--   hoef je niet aan te raken. Zonder bestand: namen van het menu en titel SPEEDRUN.
-- HANDMATIG (als het menu geen splits voor de map heeft): F6 = split, F7 = laatste split ongedaan maken,
--   met de namen en PB-tijden uit NAMES/PB hieronder.
local HOTKEY="f6"          -- handmatig: split
local UNDOKEY="f7"         -- handmatig: laatste split ongedaan maken
local FASTKEY="f8"         -- map_fast_restart
local SHOW_KEYS=false      -- zet op true om onderaan de laatst ingedrukte toets te zien
-- Grootte en plaats van het paneel. SCALE maakt het HELE paneel evenredig groter of kleiner (tekst, rijen,
-- kolommen): 1 = basisgrootte, 1.5 = anderhalf keer zo groot. Het paneel hangt rechtsboven aan het scherm.
local SCALE=1.0
local BOLD=true            -- alle tekst vet
local MARGIN_X=30          -- afstand tot de rechterrand van het scherm (pixels)
local MARGIN_Y=225         -- afstand tot de bovenkant van het scherm; hoger getal = lager op het scherm
local W=320                -- basisbreedte (wordt met SCALE vermenigvuldigd)
local MIN_H=300            -- basishoogte; wordt groter als er meer splits zijn
local FS=1.06              -- lettergrootte van alle tekst (1 = basis)
local TEXT_EDGE="shadow"   -- zwarte rand om de letters: "outline" (rand), "shadow" (schaduw rechtsonder) of "none"
local EDGE_PX=1.2          -- dikte van rand/schaduw in pixels
local VIS=6                -- aantal zichtbare splits; bij meer scrolt de lijst mee
local CHARW=0.57           -- gemiddelde letterbreedte (x tekengrootte) om rechts uit te lijnen; pas aan als
                           -- cijfers te ver links/rechts staan

local DEFAULT_TITLE="SPEEDRUN"

-- Handmatige modus (alleen als het menu geen splits voor de map heeft): namen en PB (totaaltijd per split
-- in ms, 0 = geen PB). Pas aan naar wat je wilt.
local NAMES={"Split 1","Split 2","Split 3","Split 4"}
local PB={0,0,0,0}

local ROWH=26
-- kleuren uit je totenreich.lsl
local GREEN,LGREEN,LRED,RED=0x00cc36,0x52cc73,0xfc7064,0xff1700
local CURRENT,PBBLUE,DIM,WHITE,IDLE=0x3373f4,0x16a6ff,0x9a9ea6,0xffffff,0xacacac
local GOLD=0xd8af1f      -- split die je snelste segment ooit was (BestSegmentColor uit je .lsl)

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
local old=rawget(_G,"ZmSplitView")
if old then old.enabled=false;if old.clear then pcall(old.clear) end end
local S={enabled=true,ticks=0,splits={},lastMs=0,finished=false,cache={},raw={}}
rawset(_G,"ZmSplitView",S)

local function keySet(name)
    local set={}
    set[name]=true
    set[tostring(H(name)):lower()]=true
    return set
end
local HOT_SPLIT,HOT_UNDO,HOT_FAST=keySet(HOTKEY),keySet(UNDOKEY),keySet(FASTKEY)

local function get(object,key)
    if object==nil then return nil end
    local plain,value=pcall(function()return object[key]end)
    if plain and value~=nil then return value end
    local ok,hashed=pcall(function()return object[H(key)]end)
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
-- console-commando uitvoeren, zoals zm_mod_menu_post.lua dat voor het menu doet:
-- IW-engine Lua neemt (command[, controller]), Treyarch Lua (controller, command): beide proberen
local function execCommand(command)
    local engine=rawget(_G,"Engine")
    for _,name in ipairs({"Exec","ExecNow"}) do
        local run=get(engine,name)
        if type(run)=="function" then
            local ok=pcall(run,command)
            if not ok then ok=pcall(run,0,command) end
            if ok then return true end
        end
    end
    return false
end

local function newElement(kind)
    local f=get(get(rawget(_G,"LUI"),kind),"new")
    if type(f)~="function" then error("Native "..kind.." constructor unavailable",0) end
    return f()
end
local function passive(element)
    call(element,"SetHandleMouse",false);call(element,"setFocusable",false)
end
-- zwarte kopieen van een tekst, iets verschoven achter de tekst zelf: geeft een rand of schaduw
local EDGE_OFFSETS={}
if TEXT_EDGE=="outline" then
    EDGE_OFFSETS={{-EDGE_PX,-EDGE_PX},{EDGE_PX,-EDGE_PX},{-EDGE_PX,EDGE_PX},{EDGE_PX,EDGE_PX}}
elseif TEXT_EDGE=="shadow" then
    EDGE_OFFSETS={{EDGE_PX*1.4,EDGE_PX*1.4}}
end
local function place(node,x,y,w,h)
    call(node,"SetAnchorsAndPosition",0,1,0,1,x*SCALE,(x+w)*SCALE,y*SCALE,(y+h)*SCALE)
    local copies=S.edge and S.edge[node]
    if copies then
        for i,c in ipairs(copies) do
            local o=EDGE_OFFSETS[i]
            call(c,"SetAnchorsAndPosition",0,1,0,1,(x+o[1])*SCALE,(x+w+o[1])*SCALE,(y+o[2])*SCALE,(y+h+o[2])*SCALE)
        end
    end
end
local function plainLabel(parent,x,y,w,h,size,rgb,bold)
    local element=newElement("UIStyledText")
    place(element,x,y,w,h)
    local fonts=rawget(_G,"FONT_HANDLE")
    local font=((bold or BOLD) and get(fonts,"PrimaryBold")) or get(fonts,"TertiaryMedium") or get(fonts,"SecondaryRegular") or get(fonts,"PrimaryBold") or get(fonts,"PrimaryRegular")
    if font then call(element,"SetFont",font) end
    call(element,"SetFontSize",size*FS*SCALE*(tonumber(rawget(_G,"_PT")) or 1))
    call(element,"SetRGB",rgb);call(element,"SetAlignment",0)
    passive(element);call(parent,"addElement",element)
    return element
end
local function label(parent,x,y,w,h,size,rgb,bold)
    local copies
    if #EDGE_OFFSETS>0 then
        copies={}
        for i,o in ipairs(EDGE_OFFSETS) do
            copies[i]=plainLabel(parent,x+o[1],y+o[2],w,h,size,0x000000,bold)
        end
    end
    local element=plainLabel(parent,x,y,w,h,size,rgb,bold)
    if copies then
        if not S.edge then S.edge={} end
        S.edge[element]=copies
    end
    return element
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

local function rectangle(parent,x,y,w,h,rgb,alpha)
    local element=newElement("UIImage")
    place(element,x,y,w,h)
    call(element,"SetRGB",rgb);call(element,"SetAlpha",alpha)
    passive(element);call(parent,"addElement",element)
    return element
end

-- de bestanden zm_split_<map>_post.lua zetten hun gegevens in deze tabel (volgorde van laden maakt niet uit:
-- we lezen hem pas als we iets tekenen)
local function mapConfig(name)
    local all=rawget(_G,"ZMSPLIT_MAPS")
    if type(all)=="table" and name and name~="" then return all[name] end
end

-- 83123 ms -> "1:23","12" ; boven het uur "1:02:03","12"
local function parts(ms)
    ms=math.max(0,math.floor(ms))
    local cs=math.floor(ms/10)
    local s=math.floor(cs/100)
    local h=math.floor(s/3600)
    local m=math.floor((s%3600)/60)
    local main
    if h>0 then main=string.format("%d:%02d:%02d",h,m,s%60) else main=string.format("%d:%02d",m,s%60) end
    return main,string.format(".%02d",cs%100)
end
-- 710785 ms -> 11:50
local function fmtSec(ms)
    local s=math.floor(math.max(0,ms)/1000)
    return string.format("%d:%02d",math.floor(s/60),s%60)
end
-- 348400 ms -> 5:48.4
local function fmtTenth(ms)
    local t=math.floor(math.max(0,ms)/100)
    return string.format("%d:%02d.%d",math.floor(t/600),math.floor((t%600)/10),t%10)
end
-- +3.2 / -1:05.3
local function fmtDelta(d)
    local sign=d<0 and "-" or "+"
    local t=math.floor(math.abs(d)/100)
    local m=math.floor(t/600)
    local s=math.floor((t%600)/10)
    if m>0 then return string.format("%s%d:%02d.%d",sign,m,s,t%10) end
    return string.format("%s%d.%d",sign,s,t%10)
end

-- "a|b|c" of "1,2,3" uit een dvar, alleen opnieuw ontleed als de tekst veranderd is
local function list(dvar,pattern,numeric)
    local raw=read(dvar) or ""
    local c=S.raw[dvar]
    if c and c.raw==raw then return c.list end
    local out={}
    for token in raw:gmatch(pattern) do
        out[#out+1]=numeric and (tonumber(token) or 0) or token
    end
    S.raw[dvar]={raw=raw,list=out}
    return out
end

-- breedte per teken (in tekengroottes): cijfers breed, punt/dubbele punt smal. Zo klopt de plaats van de
-- decimalen naast de grote timer; CHARW is een algemene correctie (groter = alles breder geschat).
local function tw(text,size)
    local em=0
    for i=1,#text do
        local ch=text:sub(i,i)
        if ch=="1" then em=em+0.34
        elseif ch:match("%d") then em=em+0.53
        elseif ch==":" or ch=="." or ch=="," or ch==" " then em=em+0.28
        elseif ch=="+" then em=em+0.55
        elseif ch=="-" then em=em+0.38
        elseif ch:match("%u") then em=em+0.46
        else em=em+0.55 end
    end
    return em*size*FS*CHARW/0.57
end
-- zet tekst/kleur alleen als ze veranderd zijn
local function put(el,text,rgb)
    local c=S.cache[el]
    if not c then c={};S.cache[el]=c end
    if c.text~=text then
        call(el,"setText",text);c.text=text
        local copies=S.edge and S.edge[el]
        if copies then for _,e in ipairs(copies) do call(e,"setText",text) end end
    end
    if rgb and c.rgb~=rgb then call(el,"SetRGB",rgb);c.rgb=rgb end
end
-- rechts uitgelijnd op x=right: positie volgt de tekstlengte
local function putR(el,text,rgb,right,y,h,size)
    local c=S.cache[el]
    if not c then c={};S.cache[el]=c end
    if c.px~=text then
        local width=tw(text,size)
        place(el,right-width,y,width+24,h)
        c.px=text
    end
    put(el,text,rgb)
end
local function putC(el,text,rgb,y,h,size)
    local c=S.cache[el]
    if not c then c={};S.cache[el]=c end
    if c.px~=text then
        local width=tw(text,size)
        place(el,(W-width)/2,y,width+24,h)
        c.px=text
    end
    put(el,text,rgb)
end
local function alpha(el,value)
    local c=S.cache[el]
    if not c then c={};S.cache[el]=c end
    if c.alpha~=value then call(el,"SetAlpha",value);c.alpha=value end
end

-- hoogtes (y) in het frame
local TITLE_Y,LABEL_Y,ROWS_Y=0,26,44
local DR,TR=W-62,W-6        -- rechterrand van de +/- kolom en van de Time kolom
local function heightFor(rc)
    return ROWS_Y+rc*ROWH+8+52+6+40+4+20+22
end
local HEIGHT=math.max(MIN_H,heightFor(VIS))

local function clear()
    if S.frame then pcall(call,S.frame,"closeTree") end
    S.frame=nil;S.parent=nil;S.rows=nil;S.title=nil;S.dbg=nil;S.rc=nil;S.edge=nil
    S.cache={}
end

local function build(parent)
    clear()
    local frame=newElement("UIElement")
    call(frame,"SetAlpha",1);call(frame,"setPriority",1000);passive(frame);call(parent,"addElement",frame)
    call(frame,"SetAnchorsAndPosition",1,0,0,1,-W*SCALE-MARGIN_X,-MARGIN_X,MARGIN_Y,MARGIN_Y+HEIGHT*SCALE)
    S.frame=frame;S.parent=parent
    S.title=label(frame,0,TITLE_Y,W,24,20,WHITE,true)
    S.colDelta=label(frame,DR-30,LABEL_Y,40,16,13,WHITE,true)
    S.colTime=label(frame,TR-30,LABEL_Y,40,16,13,WHITE,true)
    S.rows={}
    for i=1,VIS do
        local y=ROWS_Y+(i-1)*ROWH
        local hl=rectangle(frame,0,y,W,ROWH,CURRENT,0)
        S.rows[i]={
            hl=hl,
            name=label(frame,6,y+2,150,ROWH,17,WHITE,true),
            delta=label(frame,DR-60,y+2,70,ROWH,17,WHITE),
            time=label(frame,TR-60,y+2,70,ROWH,17,WHITE),
        }
    end
    S.big=label(frame,0,0,120,52,44,WHITE,true)
    S.bigd=label(frame,0,0,60,52,28,WHITE,true)
    S.pbl=label(frame,6,0,120,16,13,WHITE,true)
    S.bestl=label(frame,6,0,120,16,13,WHITE,true)
    S.seg=label(frame,0,0,120,40,30,WHITE,true)
    S.segd=label(frame,0,0,60,40,20,WHITE,true)
    S.ptsl=label(frame,6,0,160,18,13,WHITE,true)
    S.ptsv=label(frame,0,0,90,18,13,WHITE,true)
    S.sobl=label(frame,6,0,160,18,13,WHITE,true)
    S.sobv=label(frame,0,0,90,18,13,WHITE,true)
    S.dbg=label(frame,0,0,W,18,12,DIM)
end

-- handmatige modus: een afgeronde run die sneller was dan je PB wordt de PB voor de rest van de sessie
-- (zet de nieuwe tijden daarna in PB bovenin dit bestand om ze te bewaren)
local N=math.min(#NAMES,#PB)
local function newRun()
    if S.finished and S.finalMs and (PB[N]==0 or S.finalMs<PB[N]) then
        for i=1,N do PB[i]=S.splits[i].ms end
    end
    S.splits={};S.finished=false;S.finalMs=nil
end

-- AUTO: alles komt uit de dvars van zm_splitter.gsc, aangevuld met het bestand van de map
local function autoView(ms)
    local names=list("zm_srnames","[^|]+",false)
    local pb=list("zm_srpb","[^,]+",true)
    local times=list("zm_srt","[^,]+",true)
    local cfg=mapConfig(read("zm_srmap"))
    -- nog geen PB van het menu: de startvergelijking van deze map (als hij evenveel splits heeft)
    local seed=cfg and (cfg.pb or cfg.seed)
    if #pb==0 and seed and #seed==#names then pb=seed end
    local total=#names
    local finished=total>0 and #times>=total
    local last=pb[total]
    -- beste segmenten: de mod houdt ze zelf bij (zm_srbest); het kaartbestand vult aan waar nog niets is
    return {names=names,pb=pb,times=times,shown=ms,cfg=cfg,best=list("zm_srbest","[^,]+",true),
        newpb=finished and (not last or last==0 or times[total]<last)}
end

-- HANDMATIG: F6 / F7 / console
local function manualView(ms)
    -- de klok begon opnieuw (nieuwe match): nieuwe run
    if ms<S.lastMs-1000 then newRun() end
    S.lastMs=ms
    local request=S.splitRequest
    S.splitRequest=false
    -- console: "zm_split 1" geeft ook een split
    if read("zm_split")=="1" then
        request=true
        local set=get(rawget(_G,"Dvar"),"SetDvarString")
        if type(set)=="function" then pcall(set,HD("zm_split"),"0") end
    end
    if S.undoRequest then
        S.undoRequest=false
        if #S.splits>0 then S.splits[#S.splits]=nil;S.finished=false;S.finalMs=nil end
    end
    if request and ms>0 and #S.splits<N then
        S.splits[#S.splits+1]={ms=ms}
        if #S.splits==N then S.finished=true;S.finalMs=ms end
    end
    local times={}
    for i,sp in ipairs(S.splits) do times[i]=sp.ms end
    return {names=NAMES,pb=PB,times=times,shown=S.finished and S.finalMs or ms,
        cfg={title="HANDMATIG (F6 / F7)"},newpb=S.finished and (PB[N]==0 or S.finalMs<PB[N])}
end

local function validPb(view,i)
    local p=view.pb[i]
    if p and p>0 then return p end
end
-- LiveSplit-kleuren: voor/achter, en winnen of verliezen ten opzichte van de vorige split
local function deltaColor(view,idx,d)
    local prev=0
    if idx>1 then
        local pp=validPb(view,idx-1)
        if pp and view.times[idx-1] then prev=view.times[idx-1]-pp end
    end
    local gaining=d<prev
    if d<0 then return gaining and GREEN or LGREEN end
    return gaining and LRED or RED
end

local function displayName(view,idx)
    local original=view.names[idx]
    local cfg=view.cfg
    if cfg then
        if cfg.names and cfg.names[idx] and #cfg.names==#view.names then return cfg.names[idx] end
        if cfg.rename and cfg.rename[original] then return cfg.rename[original] end
    end
    return original
end
-- te lange namen worden afgekapt met een punt, zodat ze niet in de +/- kolom lopen
-- (kortere naam kiezen kan met rename in het kaartbestand van de map)
local function fitName(name)
    local maxc=math.floor((DR-66)/(17*FS*CHARW))
    if #name>maxc then return string.sub(name,1,maxc-1).."." end
    return name
end

local function render(view)
    local total=#view.names
    local done=#view.times
    local shown=view.shown
    local cfg=view.cfg
    local timerOnly=view.timerOnly
    local rc=timerOnly and 0 or math.min(VIS,total)
    local cur=math.min(done+1,total)
    -- de lijst scrolt zo dat de huidige split op de derde regel staat
    local first=1
    if total>VIS then first=math.max(1,math.min(done-1,total-VIS+1)) end
    for i=1,VIS do
        local r=S.rows[i]
        local idx=first+i-1
        local y=ROWS_Y+(i-1)*ROWH+2
        local name,dtext,drgb,ttext="","",WHITE,""
        local isCurrent=false
        if idx<=total and not timerOnly then
            name=fitName(displayName(view,idx))
            local p=validPb(view,idx)
            if idx<=done then
                -- oefenen: tijd 0 = split die je overslaat; geen delta (de tijd is een segment, geen totaal)
                if view.times[idx]<=0 then
                    ttext="-"
                else
                    if p then
                        local d=view.times[idx]-p
                        dtext=fmtDelta(d);drgb=deltaColor(view,idx,d)
                        -- goud: dit segment was je snelste ooit (de mod heeft het beste segment al bijgewerkt)
                        local b=view.best and view.best[idx]
                        local seg=view.times[idx]-(idx>1 and view.times[idx-1] or 0)
                        if b and b>0 and seg<=b then drgb=GOLD end
                    end
                    ttext=fmtSec(view.times[idx])
                end
            else
                ttext=p and fmtSec(p) or "-"
                if idx==done+1 then
                    isCurrent=true
                    if p and shown>p then dtext=fmtDelta(shown-p);drgb=RED end
                end
            end
        end
        alpha(r.hl,isCurrent and 0.9 or 0)
        put(r.name,name,WHITE)
        if dtext~="" then putR(r.delta,dtext,drgb,DR,y,ROWH,17) else put(r.delta,"",drgb) end
        if ttext~="" then putR(r.time,ttext,WHITE,TR,y,ROWH,17) else put(r.time,"",WHITE) end
    end
    -- onder de rijen: grote timer, segmenttimer, PB / Best, Possible Time Save
    local bigY=ROWS_Y+rc*ROWH+8
    local segY=bigY+58
    if rc~=S.rc then
        place(S.big,0,bigY,120,52)
        place(S.bigd,0,bigY+14,60,38)
        place(S.pbl,6,segY+2,150,16)
        place(S.bestl,6,segY+20,150,16)
        place(S.seg,0,segY,120,40)
        place(S.segd,0,segY+8,60,32)
        place(S.ptsl,6,segY+44,170,18)
        place(S.ptsv,0,segY+44,90,18)
        place(S.sobl,6,segY+66,170,18)
        place(S.sobv,0,segY+66,90,18)
        place(S.dbg,0,segY+88,W,18)
        S.rc=rc
        S.cache[S.big]=nil;S.cache[S.bigd]=nil;S.cache[S.seg]=nil;S.cache[S.segd]=nil;S.cache[S.ptsv]=nil;S.cache[S.sobv]=nil
        call(S.frame,"SetAnchorsAndPosition",1,0,0,1,-W*SCALE-MARGIN_X,-MARGIN_X,MARGIN_Y,MARGIN_Y+math.max(MIN_H,heightFor(rc))*SCALE)
    end
    putC(S.title,(cfg and cfg.title) or DEFAULT_TITLE,WHITE,TITLE_Y,24,22)
    putR(S.colDelta,timerOnly and "" or "+/-",WHITE,DR,LABEL_Y,16,13)
    putR(S.colTime,timerOnly and "" or "Time",WHITE,TR,LABEL_Y,16,13)

    -- kleur van de grote timer: voor/achter op je PB bij de huidige split
    local timerRgb=WHITE
    local finished=total>0 and done>=total
    if shown<=0 then timerRgb=IDLE
    elseif view.newpb then timerRgb=PBBLUE
    else
        local p=validPb(view,finished and total or cur)
        if p then timerRgb=shown<=p and GREEN or RED end
    end
    local main,dec=parts(shown)
    local decW=tw(dec,28)
    local x2=W-6-decW
    local x1=x2-tw(main,44)
    local c=S.cache[S.big]
    if not c then c={};S.cache[S.big]=c end
    if c.px~=main then place(S.big,x1,bigY,tw(main,44)+24,52);c.px=main end
    c=S.cache[S.bigd]
    if not c then c={};S.cache[S.bigd]=c end
    if c.px~=dec then place(S.bigd,x2,bigY+14,decW+24,38);c.px=dec end
    put(S.big,main,timerRgb);put(S.bigd,dec,timerRgb)

    -- segmenttimer: tijd sinds de vorige split
    local segStart=0
    if done>0 then segStart=view.times[math.min(done,#view.times)] or 0 end
    local segMs=shown-segStart
    if finished then segMs=(view.times[total] or 0)-(view.times[total-1] or 0) end
    local sm,sd=parts(segMs)
    local sdW=tw(sd,20)
    local sx2=W-6-sdW
    local sx1=sx2-tw(sm,30)
    c=S.cache[S.seg]
    if not c then c={};S.cache[S.seg]=c end
    if c.px~=sm then place(S.seg,sx1,segY,tw(sm,30)+24,40);c.px=sm end
    c=S.cache[S.segd]
    if not c then c={};S.cache[S.segd]=c end
    if c.px~=sd then place(S.segd,sx2,segY+8,sdW+24,32);c.px=sd end
    put(S.seg,sm,WHITE);put(S.segd,sd,WHITE)

    -- PB-segment (duur van de huidige split in je PB) en beste segment (uit het mapbestand)
    local segPb
    local pcur=validPb(view,cur)
    if pcur then
        if cur==1 then segPb=pcur
        else
            local pprev=validPb(view,cur-1)
            if pprev then segPb=pcur-pprev end
        end
    end
    local best=view.best and view.best[cur]
    if not best or best<=0 then best=cfg and cfg.best and cfg.best[cur] end
    if best and best<=0 then best=nil end
    put(S.pbl,segPb and not timerOnly and ("PB: "..fmtTenth(segPb)) or "",WHITE)
    put(S.bestl,best and not timerOnly and ("Best: "..fmtTenth(best)) or "",WHITE)
    if segPb and best and not timerOnly then
        put(S.ptsl,"Possible Time Save",WHITE)
        putR(S.ptsv,fmtTenth(math.max(0,segPb-best)),WHITE,W-6,segY+44,18,13)
    else
        put(S.ptsl,"",WHITE);put(S.ptsv,"",WHITE)
    end
    -- Sum of Best: de som van je beste segmenten, alleen als ze van elke split bekend zijn
    local sum,known=0,total>0
    for i=1,total do
        local b=view.best and view.best[i]
        if not b or b<=0 then b=cfg and cfg.best and cfg.best[i] end
        if b and b>0 then sum=sum+b else known=false end
    end
    if known and not timerOnly then
        put(S.sobl,"Sum of Best",WHITE)
        putR(S.sobv,fmtTenth(sum),WHITE,W-6,segY+66,18,13)
    else
        put(S.sobl,"",WHITE);put(S.sobv,"",WHITE)
    end
    put(S.dbg,SHOW_KEYS and ("toets: "..(S.lastKey or "-")) or "",DIM)
end

-- echte tijd voor de GSC (zm_rt, ms): loopt door als het spel pauzeert, gettime() niet
-- os.clock is op Windows de wandklok sinds de start van het spel; anders Engine.GetSystemTime (seconden)
local RT=rawget(_G,"ZmRealTime") or {}
rawset(_G,"ZmRealTime",RT)
local function wallMs()
    if type(os)=="table" and type(os.clock)=="function" then
        local ok,c=pcall(os.clock)
        if ok and type(c)=="number" then RT.fine=true;return c*1000 end
    end
    local ok,sec=pcall(invoke,rawget(_G,"Engine"),"GetSystemTime")
    if ok and type(sec)=="number" then
        if sec~=math.floor(sec) then RT.fine=true end
        return sec*1000
    end
end
local function writeRealTime()
    local now=wallMs()
    if not now then return end
    if not RT.base then RT.base=now end
    local set=get(rawget(_G,"Dvar"),"SetDvarString")
    if type(set)~="function" then return now end
    pcall(set,HD("zm_rt"),tostring(math.floor(now-RT.base)+1))
    pcall(set,HD("zm_rtq"),RT.fine and "1" or "0")
    return now
end

local function tick()
    S.ticks=S.ticks+1
    -- F8: map_fast_restart
    if S.execRequest then
        local command=S.execRequest
        S.execRequest=nil
        if inMatch() then execCommand(command) end
    end
    if not inMatch() then
        if S.frame then clear() end
        newRun();S.lastMs=0;S.splitRequest=false;S.undoRequest=false;S.raw={}
        return
    end
    local now=writeRealTime()
    local ms=tonumber(read("zm_tms") or "")
    local parent=displayParent()
    if not ms or not parent then return end
    -- de GSC schrijft zm_tms per server-frame en niet tijdens de pauze: tussendoor loopt de timer
    -- hier verder op de wandklok, elke frame, en nooit terug (een nieuwe run zakt meer dan 1 s)
    if ms~=S.rtMs or not now then S.rtMs=ms;S.rtAt=now end
    if read("zm_trun")=="1" and now and S.rtAt then
        local shown=ms+math.floor(now-S.rtAt)
        if S.shown and shown<S.shown and shown>S.shown-1000 then shown=S.shown end
        S.shown=shown;ms=shown
    else
        S.shown=nil
    end
    local mode=read("zm_sr")
    -- de GSC wacht nog op de splits van het menu (net na het laden): nog niets tonen
    if mode=="2" then
        if S.frame then clear() end
        return
    end
    -- pause-menu opties van FuzSpeedrun: Timer uit = niets tonen, "timer" = alleen de timer
    if read("zmm_ptimer")=="0" then
        if S.frame then clear() end
        return
    end
    local view
    if mode=="1" then
        S.splitRequest=false;S.undoRequest=false
        view=autoView(ms)
    else
        view=manualView(ms)
    end
    view.timerOnly=read("zmm_pshow")=="0"
    if not S.frame or S.parent~=parent then build(parent) end
    render(view)
end

-- native UI timer (zelfde techniek als zm_mod_menu_post.lua): een verborgen element met Wait(16), steeds opnieuw
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
    local okParent,parent=pcall(call,S.host,"getParent")
    if okParent and parent==root then return end
    if S.host then pcall(call,S.host,"closeTree") end
    S.host=nil
    pcall(function()
        local host=newElement("UIElement")
        passive(host);call(root,"addElement",host);S.host=host
        local function schedule()
            if not S.enabled or S.host~=host then return end
            local animation=call(host,"Wait",16)
            if not animation then S.host=nil;return end
            animation.onComplete=function()
                if not S.enabled or S.host~=host then return end
                local ok=pcall(tick)
                if not ok then clear() end
                pcall(schedule)
            end
        end
        schedule()
    end)
end
S.ensureTimer=ensureTimer;S.clear=clear

-- toetsen opvangen: we kijken alleen mee en laten de toets gewoon door
local function onKey(down,button,key)
    if down~=true then return end
    local b,k=tostring(button):lower(),tostring(key):lower()
    S.lastKey=k.." | "..b
    if HOT_SPLIT[k] or HOT_SPLIT[b] then S.splitRequest=true end
    if HOT_UNDO[k] or HOT_UNDO[b] then S.undoRequest=true end
    if HOT_FAST[k] or HOT_FAST[b] then S.execRequest="map_fast_restart" end
end

local installed=setmetatable({},{__mode="k"})
local function install()
    local input=get(rawget(_G,"LUI"),"UIRoot")
    local original=get(input,"QueueInput")
    if type(original)~="function" or installed[input] then return end
    local wrapped=function(...)
        if S.enabled then
            pcall(ensureTimer)
            local _,c,_,down,button,_,_,_,_,_,key=...
            pcall(onKey,down,button,key)
        end
        return original(...)
    end
    installed[input]=true
    input.QueueInput=wrapped;input[H("QueueInput")]=wrapped
end
pcall(ensureTimer)
pcall(install)
