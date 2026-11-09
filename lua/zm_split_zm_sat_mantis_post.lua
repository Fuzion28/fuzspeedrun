-- Splitter-gegevens voor deze map (zm_sat_mantis, Paradox Junction). Bestand vervangen of weghalen = alleen deze map verandert.
-- title : titel boven de splits
-- rename: naam van het menu -> naam die jij wilt zien (leeg = de namen van het menu)
-- best  : beste segmenttijd in ms per split (0 = onbekend); de mod houdt dit zelf bij, dit vult alleen aan
local all=rawget(_G,"ZMSPLIT_MAPS")
if type(all)~="table" then all={};rawset(_G,"ZMSPLIT_MAPS",all) end
all["zm_sat_mantis"]={
    title="PARADOX JUNCTION",
    rename={},
    best={}
}
