-- Splitter-gegevens voor deze map (zm_sat_ruby). Bestand vervangen of weghalen = alleen deze map verandert.
-- title : titel boven de splits
-- rename: naam van het menu -> naam die jij wilt zien (de splits zelf bepaalt het menu)
-- pb    : startvergelijking in ms per split (0 = geen), alleen tot je eerste voltooide run; moet evenveel
--         getallen hebben als de map splits heeft
-- best  : beste segmenttijd in ms per split (0 = onbekend) voor "Best" en "Possible Time Save"
local all=rawget(_G,"ZMSPLIT_MAPS")
if type(all)~="table" then all={};rawset(_G,"ZMSPLIT_MAPS",all) end
all["zm_sat_ruby"]={
    title="ASTRA MALORUM",
    rename={},
    best={}
}
