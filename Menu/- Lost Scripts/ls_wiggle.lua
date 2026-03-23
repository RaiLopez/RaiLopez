-- **************************************************
-- Provide Moho with the name of this script object
-- **************************************************

ScriptName = "LS_Wiggle"
ScriptBirth = "20231022-0415"
ScriptBuild = "20251023-0011"
ScriptTarget = "14.4 Pro"
ScriptDep={"Utility/ls_other.lua","Modules/ls_modules.lua"}

-- **************************************************
-- General information about this script
-- **************************************************

LS_Wiggle = LS_Wiggle or {}

-- **************************************************
-- Recurring values
-- **************************************************

LS_Wiggle.LM_TransformLayer = {}
LS_Wiggle.LM_TransformLayer.mode = 0
LS_Wiggle.LM_TransformLayer.dragging = false

-- 20260318-0025
-- 20260321-0111