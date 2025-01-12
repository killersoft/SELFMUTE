# SELFMUTE
SOURCEMOD SELFMUTE 2024 REWRITE of : https://forums.alliedmods.net/showthread.php?t=302320
Compiled under last version of Sourcemod v1.11 
Fixes :

The biggest change is that getFilterName has been replaced with GetFilterName which now writes its result to a caller-supplied buffer (rather than returning a local array). Additionally, string assignments are done with strcopy or FormatEx, and a few other housekeeping details are addressed ( clarifying parentheses, etc.).


Key Fixes & Notes:

    GetFilterName (instead of getFilterName) now writes to a caller-provided buffer using strcopy and FormatEx. This avoids returning a local char[] pointer which is invalid after the function returns.
    String assignments:
    e.g    strcopy(textNames, sizeof(textNames), ""); for clearing.
    Clarified parentheses in certain if checks.
    Minor improvements to sorting logic, bubble sort pass variables, etc.
