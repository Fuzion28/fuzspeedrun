-- Splitter-gegevens voor deze map (zm_sat_scarab, Rex Infurnus). Bestand vervangen of weghalen = alleen deze map verandert.
-- title : titel boven de splits
-- rename: naam van het menu -> naam die jij wilt zien (leeg = de namen van het menu)
-- pb    : startvergelijking in ms (cumulatief per split), alleen tot de eerste voltooide run (easter egg, uit oude LiveSplit)
-- best  : beste segmenttijd in ms per split (0 = onbekend); de mod houdt dit zelf bij, dit vult alleen aan
local all=rawget(_G,"ZMSPLIT_MAPS")
if type(all)~="table" then all={};rawset(_G,"ZMSPLIT_MAPS",all) end
all["zm_sat_scarab"]={
    title="REX INFERNUS",
    rename={},
    pb={269115,1123583,3272392,3776698,4720847},
    best={269115,840316,2116912,504306,433984}
}
