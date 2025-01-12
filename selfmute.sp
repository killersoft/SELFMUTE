/*  Copyright (C) 2024 KILLERSOFT
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/
#pragma newdecls required
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#include <colors_csgo>

#define BOTS false // false == debugging with bots

bool MuteStatus[MAXPLAYERS+1][MAXPLAYERS+1];
char clientNames[MAXPLAYERS+1][MAX_NAME_LENGTH];

float clientTalkTime[MAXPLAYERS+1] = { 0.0 };
ConVar sm_selfmute_admin, sm_selfmute_talk_seconds, sm_selfmute_spam_mutes, sv_alltalk;

public Plugin myinfo = 
{
    name = "Self-Mute JAN_2024",
    author = "KILLERSOFT, BASED ON IT-KiLLER( el.at ) 1.5.2 version",
    description = "Mute player just for each client to self use",
    version = "1",
    url = "https://github.com/IT-KiLLER"
}

public void OnPluginStart() 
{   
    LoadTranslations("common.phrases");
    RegConsoleCmd("sm_sm", selfMute, "Mute player by typing !selfmute <name>");
    RegConsoleCmd("sm_su", selfUnmute, "Unmute player by typing !su <name>");
    sm_selfmute_admin = CreateConVar("sm_selfmute_admin", "1.0", "Admin can not be muted. Disabled by default", _, true, 0.0, true, 1.0);
    sm_selfmute_talk_seconds = CreateConVar("sm_selfmute_talk_seconds", "45.0", "List clients who have recently spoken within x seconds", _, true, 1.0, true, 180.0);
    sm_selfmute_spam_mutes = CreateConVar("sm_selfmute_spam_mutes", "4.0", "How many mutes a client needs to get listed as spammer.", _, true, 1.0, true, 64.0);
}

public void OnAllPluginsLoaded()
{
    sv_alltalk = FindConVar("sv_full_alltalk");
    if (!sv_alltalk) 
    {
        sv_alltalk = FindConVar("sv_alltalk");
    }
}

public void OnPluginEnd()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        for (int target = 1; target <= MaxClients; target++)
        {
            if (IsClientInGame(client) && IsClientInGame(target))
            {
                SetListenOverride(client, target, Listen_Default);
            }
        }
    }
}

public void OnMapStart()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client))
        {
            clientTalkTime[client] = 0.0;
        }
    }
}

public void OnClientDisconnect(int client)
{
    if (client)
    {
        clientTalkTime[client] = 0.0;
    }
}

public void OnClientPutInServer(int client)
{
    // Reset mute status from all existing players to this new client
    for (int target = 1; target <= MaxClients; target++)
    {
        if (IsClientInGame(target))
        {
            MuteStatus[target][client] = false;
            if (target != client)
            {
                SetListenOverride(target, client, Listen_Default);
            }
        }
    }
}

public void OnClientSpeakingEx(int client)
{
    if (GetClientListeningFlags(client) == VOICE_MUTED) return;
    clientTalkTime[client] = GetGameTime();
}

public void OnClientSpeakingEnd(int client)
{
    if (GetClientListeningFlags(client) == VOICE_MUTED) return;
    clientTalkTime[client] = GetGameTime();
}

Action selfMute(int client, int args)
{
    if (client)
    {
        if (args < 1) 
        {
            DisplayMuteMenu(client);
            return Plugin_Handled;
        }
        
        char strTarget[MAX_NAME_LENGTH];
        GetCmdArg(1, strTarget, sizeof(strTarget)); 

        if (StrEqual(strTarget, "@me"))
        {
            CPrintToChat(client, "{green}[SM]{red} You cannot mute yourself.");
            return Plugin_Handled; 
        }

        char strTargetName[MAX_TARGET_LENGTH]; 
        int TargetList[MAXPLAYERS], TargetCount; 
        bool TargetTranslate;

        // Use the standard target processing
        TargetCount = ProcessTargetString(strTarget, 0, TargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, 
                                          strTargetName, sizeof(strTargetName), TargetTranslate);
        if (TargetCount <= 0) 
        {
            ReplyToTargetError(client, TargetCount); 
            return Plugin_Handled; 
        }

        muteTargetedPlayers(client, TargetList, TargetCount, strTarget);
    }
    return Plugin_Handled;
}

stock void DisplayMuteMenu(int client)
{
    Menu menu = CreateMenu(MenuHandler_MuteMenu);
    menu.SetTitle("Self-Mute Intelligence");
    menu.ExitButton = true;
    menu.ExitBackButton = true;
    float gametime = GetGameTime();

    bool clientAlreadyListed[MAXPLAYERS + 1];
    clientAlreadyListed[client] = true; // Exclude self from listing

    // Sort array of clients by last talk time
    // We'll store them in clientSortRecentlyTalked and reorder it
    int clientSortRecentlyTalked[MAXPLAYERS + 1];
    for (int i = 0; i <= MaxClients; i++)
    {
        clientSortRecentlyTalked[i] = i;
    }

    // If sv_alltalk is off, you can only hear teammates, so skip listing enemies (or bots if BOTS==false)
    for (int target = 1; target <= MaxClients; target++)
    {
        if (IsClientInGame(target))
        {
            // Mark as already listed if they're not in the same voice channel or if they're a bot (if BOTS==false)
            if ((!sv_alltalk.BoolValue && !VoiceTeam(client, target)) || (BOTS && IsFakeClient(target)))
            {
                clientAlreadyListed[target] = true;
            }
        }
    }

    // Simple bubble sort by clientTalkTime (descending)
    bool loop = true;
    int temp = 0;
    int pass = 0;
    while (loop) 
    {
        loop = false;
        pass++;
        for (int i = 1; i < (MaxClients - pass); i++) 
        {
            int idx1 = clientSortRecentlyTalked[i];
            int idx2 = clientSortRecentlyTalked[i + 1];
            if (clientTalkTime[idx1] < clientTalkTime[idx2])
            {
                temp = clientSortRecentlyTalked[i];
                clientSortRecentlyTalked[i] = clientSortRecentlyTalked[i + 1];
                clientSortRecentlyTalked[i + 1] = temp;
                loop = true;
            }
        }
    }

    // 1) Add players who spoke recently
    for (int i = 1; i <= MaxClients; i++)
    {
        int target = clientSortRecentlyTalked[i];
        if (target != 0 
            && IsClientInGame(target) 
            && !clientAlreadyListed[target] 
            && !MuteStatus[client][target] 
            && clientTalkTime[target] != 0.0 
            && (clientTalkTime[target] + sm_selfmute_talk_seconds.FloatValue) > gametime)
        {
            clientAlreadyListed[target] = true;

            char strClientID[12];
            char strClientName[50];
            IntToString(GetClientUserId(target), strClientID, sizeof(strClientID));
            
            float diff = gametime - clientTalkTime[target];
            if (diff <= 0.1) // Probably still speaking
            {
                FormatEx(strClientName, sizeof(strClientName), "%N (Speaking + %dM)", 
                         target, targetMutes(target, true));
            }
            else
            {
                FormatEx(strClientName, sizeof(strClientName), "%N (%.1f s + %dM)", 
                         target, diff, targetMutes(target, true));
            }
            menu.AddItem(strClientID, strClientName);
        }
    }

    // 2) Add “spammers” (players muted by many others)
    for (int target = 1; target <= MaxClients; target++)
    {
        if (IsClientInGame(target) 
            && !clientAlreadyListed[target] 
            && targetMutes(target, true) >= sm_selfmute_spam_mutes.IntValue 
            && !MuteStatus[client][target])
        {
            clientAlreadyListed[target] = true;

            char strClientID[12], strClientName[50];
            IntToString(GetClientUserId(target), strClientID, sizeof(strClientID));
            FormatEx(strClientName, sizeof(strClientName), "%N (SPAM %dM)", 
                     target, targetMutes(target, true));
            menu.AddItem(strClientID, strClientName);
        }
    }

    // 3) Alphabetical list of everyone else
    int[] alphabetClients = new int[MaxClients+1];
    for (int i = 0; i <= MaxClients; i++)
    {
        alphabetClients[i] = 0;
    }

    for (int aClient = 1; aClient <= MaxClients; aClient++)
    {
        if (IsClientInGame(aClient) && !clientAlreadyListed[aClient])
        {
            alphabetClients[aClient] = aClient;
            GetClientName(aClient, clientNames[aClient], sizeof(clientNames[]));
        }
    }
    SortCustom1D(alphabetClients, MaxClients, SortByPlayerName);

    for (int i = 0; i <= MaxClients; i++)
    {
        int aClient = alphabetClients[i];
        if (aClient != 0 
            && !clientAlreadyListed[aClient] 
            && !MuteStatus[client][aClient])
        {
            char strClientID[12], strClientName[50];
            IntToString(GetClientUserId(aClient), strClientID, sizeof(strClientID));
            FormatEx(strClientName, sizeof(strClientName), "%N", aClient);
            menu.AddItem(strClientID, strClientName);
        }
    }

    if (menu.ItemCount == 0) 
    {
        CPrintToChat(client, "{green}[SM]{lightgreen} Could not list any players, you already have muted {red}%d{lightgreen} players.", clientMutes(client));
        delete menu;
    }
    else
    {
        // If there are more than 7 items, the menu’s built-in back button is useful
        menu.ExitBackButton = (menu.ItemCount > 7);
        DisplayMenu(menu, client, MENU_TIME_FOREVER);
    }
}

int MenuHandler_MuteMenu(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End:
        {
            delete menu;          
        }

        case MenuAction_Select:
        {
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            
            int userid = StringToInt(info);
            int target = GetClientOfUserId(userid);
            if (target == 0)
            {
                CPrintToChat(param1, "{green}[SM]{red} Player no longer available");
            }
            else
            {
                // Mute single target
                int temp[1];
                temp[0] = target;
                muteTargetedPlayers(param1, temp, 1, "");
            }
            
        }
    }
    return 0;
}

void muteTargetedPlayers(int client, int[] list, int TargetCount, const char[] filtername)
{
    if (TargetCount == 1)
    {
        int target = list[0];
        if (client == target)
        {
            CPrintToChat(client, "{green}[SM]{red} You cannot mute yourself.");
            return;
        }
        if (sm_selfmute_admin.BoolValue && IsPlayerAdmin(target))
        {
            CPrintToChat(client, "{green}[SM]{red} You cannot mute an admin: {lightblue}%N", target);
            return;
        }
        if ((!sv_alltalk.BoolValue && !VoiceTeam(client, target)) || (BOTS && IsFakeClient(target)))
        {
            CPrintToChat(client, "{green}[SM]{red} The client could not be muted: {lightblue}%N", target);
            return;
        }
        SetListenOverride(client, target, Listen_No);
        MuteStatus[client][target] = true;

        CPrintToChat(client, "{green}[SM]{lightgreen} You have self-muted: %N", target);
    } 
    else if (TargetCount > 1)
    {
        char textNames[250];
        strcopy(textNames, sizeof(textNames), ""); // Initialize to empty
        int textSize = 0, countTargets = 0, target;
        
        for (int i = 0; i < TargetCount; i++) 
        {
            target = list[i];
            if (
                target == client
                || MuteStatus[client][target]
                || (sm_selfmute_admin.BoolValue && IsPlayerAdmin(target))
                || (!sv_alltalk.BoolValue && !VoiceTeam(client, target))
                || (BOTS && IsFakeClient(target))
            ) {
                continue;
            }

            countTargets++;
            MuteStatus[client][target] = true;
            SetListenOverride(client, target, Listen_No);

            FormatEx(textNames, sizeof(textNames), "%s%s%N", 
                textNames, (countTargets == 1 ? "" : ", "), target);
            textSize = strlen(textNames);
        }

        if (countTargets > 0)
        {
            char filterBuffer[30];
            GetFilterName(filtername, filterBuffer, sizeof(filterBuffer));
            CPrintToChat(client, "{green}[SM]{lightgreen} You have self-muted(%d){green}: %s", 
                countTargets, 
                (textSize <= sizeof(textNames) && countTargets <= 14) ? textNames : filterBuffer);
        }
        else 
        {
            CPrintToChat(client, "{green}[SM]{lightgreen} Everyone in the list was already muted.");
        }
    }
}

void unMuteTargetedPlayers(int client, int[] list, int TargetCount, const char[] filtername)
{
    if (TargetCount == 1)
    {
        int target = list[0];
        if (client == target)
        {
            CPrintToChat(client, "{green}[SM]{red} You cannot unmute yourself.");
            return;
        }
        SetListenOverride(client, target, Listen_Default);
        MuteStatus[client][target] = false;

        CPrintToChat(client, "{green}[SM]{lightgreen} You have self-unmuted: %N", target);
    }
    else if (TargetCount > 1)
    {
        char textNames[250];
        strcopy(textNames, sizeof(textNames), ""); // Start empty
        int textSize = 0, countTargets = 0, target;
        
        for (int i = 0; i < TargetCount; i++)
        {
            target = list[i];
            if (
                target == client
                || !MuteStatus[client][target]
                || (sm_selfmute_admin.BoolValue && IsPlayerAdmin(target))
            ) {
                continue;
            }
            countTargets++;
            SetListenOverride(client, target, Listen_Default);
            MuteStatus[client][target] = false;

            FormatEx(textNames, sizeof(textNames), "%s%s%N", 
                textNames, (countTargets == 1 ? "" : ", "), target);
            textSize = strlen(textNames);
        }

        if (countTargets > 0)
        {
            char filterBuffer[30];
            GetFilterName(filtername, filterBuffer, sizeof(filterBuffer));
            CPrintToChat(client, "{green}[SM]{lightgreen} You have self-unmuted(%d){green}: %s", 
                countTargets, 
                (textSize <= sizeof(textNames) && countTargets <= 14) ? textNames : filterBuffer);
        }
        else
        {
            CPrintToChat(client, "{green}[SM]{lightgreen} Everyone in the list was already unmuted.");
        }
    }
}

Action selfUnmute(int client, int args)
{
    if (client)
    {
        if (args < 1) 
        {
            DisplayUnMuteMenu(client);
            return Plugin_Handled;
        }
        
        char strTarget[MAX_NAME_LENGTH];
        GetCmdArg(1, strTarget, sizeof(strTarget));

        if (StrEqual(strTarget, "@me"))
        {
            CPrintToChat(client, "{green}[SM]{red} You cannot unmute yourself.");
            return Plugin_Handled; 
        }

        char strTargetName[MAX_TARGET_LENGTH];
        int TargetList[MAXPLAYERS], TargetCount; 
        bool TargetTranslate; 

        TargetCount = ProcessTargetString(strTarget, 0, TargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, 
                                          strTargetName, sizeof(strTargetName), TargetTranslate);
        if (TargetCount <= 0)
        {
            ReplyToTargetError(client, TargetCount); 
            return Plugin_Handled;
        }

        unMuteTargetedPlayers(client, TargetList, TargetCount, strTarget);
    }
    return Plugin_Handled;
}

stock void DisplayUnMuteMenu(int client)
{
    Menu menu = CreateMenu(MenuHandler_UnMuteMenu);
    menu.SetTitle("Self-unMute Intelligence");

    for (int target = 1; target <= MaxClients; target++)
    {
        if (client != target && IsClientInGame(target) && MuteStatus[client][target]) 
        {
            char strClientID[12];
            char strClientName[50];
            IntToString(GetClientUserId(target), strClientID, sizeof(strClientID));
            FormatEx(strClientName, sizeof(strClientName), "%N (M)", target);
            menu.AddItem(strClientID, strClientName);
        }
    }

    if (menu.ItemCount == 0) 
    {
        CPrintToChat(client, "{green}[SM]{lightgreen} No players are muted.");
        delete menu;
    }
    else
    {
        menu.ExitBackButton = (menu.ItemCount > 7);
        menu.Display(client, MENU_TIME_FOREVER);
    }
}

int MenuHandler_UnMuteMenu(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End:
        {
            delete menu;
        }

        case MenuAction_Select:
        {
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            
            int userid = StringToInt(info);
            int target = GetClientOfUserId(userid);
            if (target == 0)
            {
                CPrintToChat(param1, "{green}[SM]{red} Player no longer available");
            }
            else
            {
                int temp[1];
                temp[0] = target;
                unMuteTargetedPlayers(param1, temp, 1, "");
            }
        }
    }
    return 0;
}

// Checking if a client is admin
stock bool IsPlayerAdmin(int client)
{
    // This checks if they have access to a command requiring ADMFLAG_KICK
    return CheckCommandAccess(client, "Kick_admin", ADMFLAG_KICK, false);
}

stock bool VoiceTeam(int client, int target)
{
    // If sv_alltalk = 0, only teammates can hear each other
    return (!sv_alltalk.BoolValue && GetClientTeam(client) == GetClientTeam(target));
}

stock int SortByPlayerName(int player1, int player2, const int[] array, Handle hndl)
{
    return strcmp(clientNames[player1], clientNames[player2], false);
}

// Counting how many mutes a client has done
stock int clientMutes(int client)
{
    int count = 0;
    for (int target = 1; target <= MaxClients; target++)
    {
        if (MuteStatus[client][target])
        {
            count++;
        }
    }
    return count;
}

// Counting how many mutes a target has received
stock int targetMutes(int target, bool massivemute = false)
{
    int count = 0;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (MuteStatus[client][target])
        {
            if (massivemute)
            {
                int mutes = clientMutes(client);
                // Example check that client doesn't have a suspiciously high # of mutes
                // so they're still 'valid' to count as a normal muter
                if (mutes > 0 && mutes <= (MaxClients / 2))
                {
                    count++;
                }
            }
            else
            {
                count++;
            }
        }
    }
    return count;
}

/**
 * Safely writes a descriptive name of a filter (e.g., "@all", "@ct", etc.) into `out`.
 */
stock void GetFilterName(const char[] filter, char[] out, int maxLen)
{
    if (StrEqual(filter, "@all"))
    {
        strcopy(out, maxLen, "Everyone");
    }
    else if (StrEqual(filter, "@spec"))
    {
        strcopy(out, maxLen, "Spectators");
    }
    else if (StrEqual(filter, "@ct"))
    {
        strcopy(out, maxLen, "Counter-Terrorists");
    }
    else if (StrEqual(filter, "@t"))
    {
        strcopy(out, maxLen, "Terrorists");
    }
    else if (StrEqual(filter, "@dead"))
    {
        strcopy(out, maxLen, "Dead players");
    }
    else if (StrEqual(filter, "@alive"))
    {
        strcopy(out, maxLen, "Alive players");
    }
    else if (StrEqual(filter, "@!me"))
    {
        strcopy(out, maxLen, "Everyone except me");
    }
    else if (StrEqual(filter, "@admins"))
    {
        strcopy(out, maxLen, "Admins");
    }
    else
    {
        // Fallback: just output the original filter text
        FormatEx(out, maxLen, "%s", filter);
    }
}
