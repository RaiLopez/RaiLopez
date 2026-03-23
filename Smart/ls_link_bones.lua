-- **************************************************
-- Provide Moho with the name+ of this script object
-- **************************************************

ScriptName = "LS_LinkBones"
ScriptBirth = "20220918-0248"
ScriptBuild = "20260103-1852"
ScriptVersion = "0.0.0"
ScriptStage = "BETA"
ScriptTarget = "Moho® 14.4+ Pro"
ScriptDep = {""}

-- **************************************************
-- General information about this script
-- **************************************************

LS_LinkBones = {}

LS_LinkBones.BASE_STR = 2320

function LS_LinkBones:Name()
	return "Link Bones"
end

function LS_LinkBones:Version()
	return self.version -- 0.0.1.20220918.0248?
end

function LS_LinkBones:Description()
	return MOHO.Localize("/LS/LinkBones/Description=A bone linker...")
end

function LS_LinkBones:Creator()
	return "Rai López"
end

function LS_LinkBones:UILabel() -- NOTE: Runs upon dialog opening
	return(MOHO.Localize("/LS/LinkBones/LinkBones=Link Bones"))
end

function LS_LinkBones:ColorizeIcon()
	return true
end