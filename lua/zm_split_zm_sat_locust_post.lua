-- Splitter-gegevens voor deze map (zm_sat_locust, Totenreich). Bestand vervangen of weghalen = alleen deze map verandert.
-- title : titel boven de splits
-- rename: naam van het menu -> naam die jij wilt zien, bijvoorbeeld rename={["Step 1"]="CORE"}
--         (leeg = de namen van het menu)
-- pb    : startvergelijking in ms per split (0 = geen), alleen tot je eerste voltooide run; moet evenveel
--         getallen hebben als de map splits heeft. Leeg = alleen de PB die het menu bewaart.
-- best  : beste segmenttijd in ms per split (0 = onbekend) voor "Best" en "Possible Time Save"
local all=rawget(_G,"ZMSPLIT_MAPS")
if type(all)~="table" then all={};rawset(_G,"ZMSPLIT_MAPS",all) end
all["zm_sat_locust"]={
    title="TOTENREICH",
    rename={["Step 1"]="Avatar",["Step 2"]="END"},
    best={}
}
