-- **************************************************
-- Provide Moho with the name+ of this script object
-- **************************************************

ScriptName = "LS_Shapes"
ScriptBirth = "20220918-0248"
ScriptBuild = "20260103-1852"
ScriptVersion = "0.4.2"
ScriptStage = "BETA"
ScriptTarget = "14.3+ Pro"
ScriptDep = {"Utility\ls_utilities.lua", "Modules/ls.lua"}

-- **************************************************
-- General information about this script
-- **************************************************

LS_Shapes = {}

LS_Shapes.BASE_STR = 2320

function LS_Shapes:Name()
	return "Shapes Window"
end

function LS_Shapes:Version()
	return self.version -- 0.0.1.20220918.0248?
end

function LS_Shapes:Description()
	return MOHO.Localize("/LS/Shapes/Description=A persistent shape palette plus helpers for better management of Moho® vectors in general and the AMAZING new \"Liquid Shapes\" in particular.")
end

function LS_Shapes:Creator()
	return "Rai López"
end

function LS_Shapes:UILabel() -- NOTE: Runs upon dialog opening
	return(MOHO.Localize("/LS/Shapes/ShapesWindow=Shapes Window"))
end

function LS_Shapes:ColorizeIcon()
	return true
end