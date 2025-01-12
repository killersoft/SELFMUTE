# SELFMUTE
SOURCEMOD SELFMUTE 2024 REWRITE of : https://forums.alliedmods.net/showthread.php?t=302320
Compiled under last version of Sourcemod v1.11 
Fixes :

Key Fixes & Notes:

    GetFilterName (instead of getFilterName) now writes to a caller-provided buffer using strcopy and FormatEx. This avoids returning a local char[] pointer which is invalid after the function returns.
    String assignments:
        strcopy(textNames, sizeof(textNames), ""); for clearing.
        strcopy(temp, sizeof(temp), "Some string"); where needed.
   
    Clarified parentheses in certain if checks.
    Minor improvements to sorting logic, bubble sort pass variables, etc.
