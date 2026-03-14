-- **************************************************
-- Provide Moho with the name+ of this script object
-- **************************************************

ScriptName = "LS_LinkPoints"
ScriptBirth = "20220918-0248"
ScriptBuild = "20260103-1852"
ScriptVersion = "0.0.1"
ScriptStage = "BETA"
ScriptDep = {"Modules/ls_m.lua"}

-- **************************************************
-- General information about this script
-- **************************************************

LS_LinkPoints = {}

LS_LinkPoints.BASE_STR = 2320

function LS_LinkPoints:Name()
	return "Link Points"
end

function LS_LinkPoints:Version()
	return self.version -- 0.0.1.20220918.0248?
end

function LS_LinkPoints:Description()
	return MOHO.Localize("/LS/LinkPoints/Description=A point linker...")
end

function LS_LinkPoints:Creator()
	return "Rai López"
end

function LS_LinkPoints:UILabel() -- NOTE: Runs upon dialog opening
	return(MOHO.Localize("/LS/LinkPoints/LinkPoints=Link Points"))
end

function LS_LinkPoints:ColorizeIcon()
	return true
end