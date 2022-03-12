#NoEnv
#SingleInstance, Force
;;为了便于观察运行情况，需要显示托盘图标
;;#NoTrayIcon
#MaxHotkeysPerInterval 200

FileEncoding, utf-8
SendMode Input
SetWorkingDir %A_ScriptDir%

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;第一段自定义部分开始
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 1.0. 定义软件组
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;常用的几个软件组 
;;DevGroup_jet jetBrain的开发工具
;;DevGroup_ms 微软的开发工具
;;DevGroup_other 其他厂商的开发工具
;;DevGroup_all 所有类型的开发工具
;;TabGroup_all 所有拥有tab功能的应用组

GroupAdd,DevGroup_jet ,ahk_class SunAwtFrame ;所有jetBrains公司开发工具
GroupAdd,DevGroup_ms ,ahk_exe Code.exe ;ms的visual studio code
GroupAdd,DevGroup_ms ,ahk_exe devenv.exe ;ms的visual studio
GroupAdd,DevGroup_other ,ahk_exe editplus.exe
GroupAdd,DevGroup_other ,ahk_exe wechatdevtools.exe ;微信开发工具
GroupAdd,DevGroup_all ,ahk_group DevGroup_jet
GroupAdd,DevGroup_all ,ahk_group DevGroup_ms
GroupAdd,DevGroup_all ,ahk_group DevGroup_other

;;;TabGroup_all 所有拥有tab功能的应用组
GroupAdd,TabGroup_all ,ahk_group DevGroup_all
;;微软的Edge浏览器
GroupAdd,TabGroup_all ,ahk_exe msedge.exe
;;Windows的资源管理器
GroupAdd,TabGroup_all ,ahk_exe Explorer.EXE
;;稻壳阅读器
GroupAdd,TabGroup_all ,ahk_exe DocBox.exe
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 1.0. 定义软件组（结束）
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;第一段自定义部分结束
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; 自动生成的待搜索文件列表
global g_SearchFileList := A_ScriptDir . "\Conf\SearchFileList.txt"
; 用户配置的待搜索文件列表
global g_UserFileList := A_ScriptDir . "\Conf\UserFileList.txt"
; 配置文件
global g_ConfFile := A_ScriptDir . "\Conf\RunZ.ini"
; 自动写入的配置文件
global g_AutoConfFile := A_ScriptDir . "\Conf\RunZ.auto.ini"

if !FileExist(g_ConfFile)
{
    FileCopy, %g_ConfFile%.help.txt, %g_ConfFile%
}

if (FileExist(g_AutoConfFile ".EasyIni.bak"))
{
    MsgBox, % "发现上次写入配置的备份文件：`n"
        . g_AutoConfFile . ".EasyIni.bak"
        . "`n确定则将其恢复，否则请手动检查文件内容再继续"
    FileMove, % g_AutoConfFile ".EasyIni.bak", % g_AutoConfFile
}
else if (!FileExist(g_AutoConfFile))
{
    FileAppend, % "; 此文件由 RunZ 自动写入，如需手动修改请先关闭 RunZ ！`n`n"
        . "[Auto]`n[Rank]`n[History]" , % g_AutoConfFile
}

global g_Conf := class_EasyIni(g_ConfFile)
global g_AutoConf := class_EasyIni(g_AutoConfFile)

if (g_Conf.Gui.Skin != "")
{
    global g_SkinConf := class_EasyIni(A_ScriptDir "\Conf\Skins\" g_Conf.Gui.Skin ".ini").Gui
}
else
{
    global g_SkinConf := g_Conf.Gui
}

; 当前输入命令的参数，数组，为了方便没有添加 g_ 前缀
global Arg
; 用来调用管道的完整参数（所有列），供有必要的插件使用
global FullPipeArg
; 不能是 RunZ.ahk 的子串，否则按键绑定会有问题
global g_WindowName := "RunZ    "
; 所有命令
global g_Commands
; 当搜索无结果时使用的命令
global g_FallbackCommands
; 编辑框当前内容
global g_CurrentInput
; 当前匹配到的第一条命令
global g_CurrentCommand
; 当前匹配到的所有命令
global g_CurrentCommandList
; 是否启用 TCMatch
global g_EnableTCMatch = TCMatchOn(g_Conf.Config.TCMatchPath)
; 列表第一列的首字母或数字
global g_FirstChar := Asc(g_SkinConf.FirstChar)
; 在列表中显示的行数
global g_DisplayRows := g_SkinConf.DisplayRows
; 命令使用了显示框
global g_UseDisplay
; 历史命令
global g_HistoryCommands
; 运行命令时临时设置，避免因为自身退出无法运行需要提权的软件
global g_DisableAutoExit
; 当前的命令在搜索结果的行数
global g_CurrentLine
; 使用备用的命令
global g_UseFallbackCommands
; 对命令结果进行实时搜索
global g_UseResultFilter
; 当参数改变后实时重新执行命令
global g_UseRealtimeExec
; 排除的命令
global g_ExcludedCommands
; 间隔运行命令的间隔时间
global g_ExecInterval
; 上次间隔运行的功能标签
global g_LastExecLabel
; 用来调用管道的参数（结果第三列）
global g_PipeArg
; 用来补全命令用的
global g_CommandFilter
; 插件列表
global g_Plugins := Object()

global g_InputArea := "Edit1"
global g_DisplayArea := "Edit3"
global g_CommandArea := "Edit4"

FileRead, currentPlugins, %A_ScriptDir%\Core\Plugins.ahk
needRestart := false

Loop, Files, %A_ScriptDir%\Plugins\*.ahk
{
    FileReadLine, firstLine, %A_LoopFileLongPath%, 1
    pluginName := StrSplit(firstLine, ":")[2]
    if (!(g_Conf.GetValue("Plugins", pluginName) == 0))
    {
        if (RegExMatch(currentPlugins, "m)" pluginName ".ahk$"))
        {
            g_Plugins.Push(pluginName)
        }
        else
        {
            FileAppend, #include *i `%A_ScriptDir`%\Plugins\%pluginName%.ahk`n
                , %A_ScriptDir%\Core\Plugins.ahk
            needRestart := true
        }
    }
}

if (needRestart)
{
    Reload
}

if (g_SkinConf.ShowTrayIcon)
{
    Menu, Tray, Icon
    Menu, Tray, NoStandard
    if (g_Conf.Config.RunInBackground)
    {
        Menu, Tray, Add, 显示 &S, ActivateRunZ
        Menu, Tray, Default, 显示 &S
        Menu, Tray, Click, 1
    }
    Menu, Tray, Add, 配置 &C, EditConfig
    Menu, Tray, Add, 帮助 &H, KeyHelp
    Menu, Tray, Add,
    Menu, Tray, Add, 重启 &R, RestartRunZ
    Menu, Tray, Add, 退出 &X, ExitRunZ
}

Menu, Tray, Icon, %A_ScriptDir%\RunZ.ico

if (FileExist(g_SearchFileList))
{
    LoadFiles()
}
else
{
    GoSub, ReindexFiles
}

Gui, Color, % g_SkinConf.BackgroundColor, % g_SkinConf.EditColor

if (FileExist(A_ScriptDir "\Conf\Skins\" g_SkinConf.BackgroundPicture))
{
    Gui, Add, Picture, x0 y0, % A_ScriptDir "\Conf\Skins\" g_SkinConf.BackgroundPicture
}

border := 10
if (g_SkinConf.BorderSize >= 0)
{
    border := g_SkinConf.BorderSize
}
windowHeight := border * 3 + g_SkinConf.EditHeight + g_SkinConf.DisplayAreaHeight

Gui, Font, % "C" g_SkinConf.FontColor " S" g_SkinConf.FontSize, % g_SkinConf.FontName
Gui, Add, Edit, % "x" border " y" border " gProcessInputCommand -WantReturn"
        . " w" g_SkinConf.WidgetWidth " h" g_SkinConf.EditHeight,
Gui, Add, Edit, y+0 w0 h0 ReadOnly -WantReturn
Gui, Add, Button, y+0 w0 h0 Default gRunCurrentCommand
Gui, Add, Edit, % "y+" border " -VScroll ReadOnly -WantReturn"
        . " w" g_SkinConf.WidgetWidth " h" g_SkinConf.DisplayAreaHeight
        , % AlignText(SearchCommand("", true))

if (g_SkinConf.ShowCurrentCommand)
{
    Gui, Add, Edit, % "y+" border " ReadOnly"
        . " w" g_SkinConf.WidgetWidth " h" g_SkinConf.EditHeight,
    windowHeight += border + g_SkinConf.EditHeight
}

if (g_SkinConf.ShowInputBoxOnlyIfEmpty)
{
    windowHeight := border * 2 + g_SkinConf.EditHeight
    SysGet, screenHeight, 79
    windowY := "y" (screenHeight - border * 2 - g_SkinConf.EditHeight - g_SkinConf.DisplayAreaHeight) / 2
}

if (g_SkinConf.HideTitle)
{
    Gui -Caption
}

cmdlineArg = %1%
if (cmdlineArg == "--hide")
{
    hideWindow := " Hide"
}

Gui, Show, % windowY " w" border * 2 + g_SkinConf.WidgetWidth
    . " h" windowHeight hideWindow, % g_WindowName

if (g_SkinConf.RoundCorner > 0)
{
    WinSet, Region, % "0-0 w" border * 2 + g_SkinConf.WidgetWidth " h" windowHeight
        . " r" g_SkinConf.RoundCorner "-" g_SkinConf.RoundCorner, % g_WindowName
}

if (g_Conf.Config.SwitchToEngIME)
{
    SwitchToEngIME()
}

if (g_Conf.Config.WindowAlwaysOnTop)
{
    WinSet, AlwaysOnTop, On, A
}

if (g_Conf.Config.ExitIfInactivate)
{
    OnMessage(0x06, "WM_ACTIVATE")
}

OnMessage(0x0200, "WM_MOUSEMOVE")

Hotkey, IfWinActive, % g_WindowName

Hotkey, Esc, EscFunction
Hotkey, !F4, ExitRunZ

Hotkey, Tab, TabFunction
Hotkey, F1, Help
Hotkey, +F1, KeyHelp
Hotkey, F2, EditConfig
Hotkey, F3, EditAutoConfig
Hotkey, ^q, RestartRunZ
Hotkey, ^l, ClearInput
Hotkey, ^d, OpenCurrentFileDir
Hotkey, ^x, DeleteCurrentFile
Hotkey, ^s, ShowCurrentFile
Hotkey, ^r, ReindexFiles
Hotkey, ^h, DisplayHistoryCommands
Hotkey, ^n, IncreaseRank
Hotkey, ^=, IncreaseRank
Hotkey, ^p, DecreaseRank
Hotkey, ^-, DecreaseRank
Hotkey, ^f, NextPage
Hotkey, ^b, PrevPage
Hotkey, ^i, HomeKey
Hotkey, ^o, EndKey
Hotkey, ^j, NextCommand
Hotkey, ^k, PrevCommand
Hotkey, Down, NextCommand
Hotkey, Up, PrevCommand
Hotkey, ~LButton, ClickFunction
Hotkey, RButton, OpenContextMenu
Hotkey, AppsKey, OpenContextMenu
Hotkey, ^Enter, SaveResultAsArg

; 剩余按键 Ctrl + e g m t w

Loop, % g_DisplayRows
{
    key := Chr(g_FirstChar + A_Index - 1)
    ; lalt +
    Hotkey, !%key%, RunSelectedCommand
    ; tab +
    Hotkey, ~%key%, RunSelectedCommand
    ; shift +
    Hotkey, ~+%key%, GotoCommand
}

for key, label in g_Conf.Hotkey
{
    if (label != "Default")
    {
        Hotkey, %key%, %label%
    }
    else
    {
        Hotkey, %key%, Off
    }
}

Hotkey, IfWinActive

for key, label in g_Conf.GlobalHotkey
{
    if (label != "Default")
    {
        Hotkey, %key%, %label%
    }
    else
    {
        Hotkey, %key%, Off
    }
}

if (g_Conf.Config.SaveInputText && g_AutoConf.Auto.InputText != "")
{
    Send, % g_AutoConf.Auto.InputText
}

if (g_Conf.Config.SaveHistory)
{
    g_HistoryCommands := Object()
    LoadHistoryCommands()
}

UpdateSendTo(g_Conf.Config.CreateSendToLnk, false)
UpdateStartupLnk(g_Conf.Config.CreateStartupLnk, false)

SetTimer, WatchUserFileList, 3000
return

Default:
return

RestartRunZ:
    SaveAutoConf()
    Reload
return

Test:
    MsgBox, 测试
return

HomeKey:
    Send, {home}
return

EndKey:
    Send, {End}
return

NextPage:
    if (!g_UseDisplay)
    {
        return
    }

    ControlFocus, %g_DisplayArea%
    Send, {pgdn}
    ControlFocus, %g_InputArea%
return

PrevPage:
    if (!g_UseDisplay)
    {
        return
    }

    ControlFocus, %g_DisplayArea%
    Send, {pgup}
    ControlFocus, %g_InputArea%
return

ActivateRunZ:
    Gui, Show, , % g_WindowName

    if (g_Conf.Config.SwitchToEngIME)
    {
        SwitchToEngIME()
    }

    Loop, 5
    {
        Sleep, 50

        if (WinActive(g_WindowName))
        {
            ControlFocus, %g_InputArea%
            Send, ^a
            break
        }

        Gui, Show, , % g_WindowName
    }
return

ToggleWindow:
    if (WinActive(g_WindowName))
    {
        if (!g_Conf.Config.KeepInputText)
        {
            ControlSetText, %g_InputArea%, , %g_WindowName%
        }

        Gui, Hide
    }
    else
    {
        GoSub, ActivateRunZ
    }
return

getMouseCurrentLine()
{
    MouseGetPos, , mouseY, , classnn,
    if (classnn != g_DisplayArea)
    {
        return -1
    }

    ControlGetPos, , y, , h, %g_DisplayArea%
    lineHeight := h / g_DisplayRows
    index := Ceil((mouseY - y) / lineHeight)
    return index
}

ClickFunction:
    if (g_UseDisplay)
    {
        return
    }

    index := getMouseCurrentLine()
    if (index < 0)
    {
        return
    }

    if (g_CurrentCommandList[index] != "")
    {
        ChangeCommand(index - 1, true)
    }

    ControlFocus, %g_InputArea%
    Send, {end}

    if (g_Conf.Config.ClickToRun)
    {
        RunCommand(g_CurrentCommand)
    }
return

OpenContextMenu:
    if (!g_UseDisplay)
    {
        currentCommandText := ""
        if (!g_CurrentLine > 0)
        {
            currentCommandText .= Chr(g_FirstChar)
        }
        else
        {
            currentCommandText .= Chr(g_FirstChar + g_CurrentLine - 1)
        }
        Menu, ContextMenu, Add, %currentCommandText%>  运行 &Z, RunCurrentCommand
        Menu, ContextMenu, Add
    }

    Menu, ContextMenu, Add, 编辑配置 &E, EditConfig
    Menu, ContextMenu, Add, 重建索引 &S, ReindexFiles
    Menu, ContextMenu, Add, 显示历史 &H, DisplayHistoryCommands
    Menu, ContextMenu, Add, 更新路径 &C, ChangePath
    Menu, ContextMenu, Add
    Menu, ContextMenu, Add, 显示帮助 &A, Help
    Menu, ContextMenu, Add, 重新启动 &R, RestartRunZ
    Menu, ContextMenu, Add, 退出程序 &X, ExitRunZ
    Menu, ContextMenu, Show
    Menu, ContextMenu, DeleteAll
return

TabFunction:
    ControlGetFocus, ctrl,
    if (ctrl == g_InputArea)
    {
        ; 定位到一个隐藏编辑框
        ControlFocus, Edit2
    }
    else
    {
        ControlFocus, %g_InputArea%
    }
return

EscFunction:
    ToolTip
    if (g_Conf.Config.ClearInputWithEsc && g_CurrentInput != "")
    {
        GoSub, ClearInput
    }
    else
    {
        if (!g_Conf.Config.KeepInputText)
        {
            ControlSetText, %g_InputArea%, , %g_WindowName%
        }
        GoSub, HideOrExit
    }
return

HideOrExit:
    ; 如果是后台运行模式，只关闭窗口，不退出程序
    if (g_Conf.Config.RunInBackground)
    {
        Gui, Hide
    }
    else
    {
        GoSub, ExitRunZ
    }
return

NextCommand:
    if (g_UseDisplay)
    {
        ControlFocus, %g_DisplayArea%
        Send {down}
        return
    }
    ChangeCommand(1)
return

PrevCommand:
    if (g_UseDisplay)
    {
        ControlFocus, %g_DisplayArea%
        Send {up}
        return
    }
    ChangeCommand(-1)
return

GotoCommand:
    ControlGetFocus, ctrl,
    if (ctrl == g_InputArea)
    {
        return
    }

    index := Asc(SubStr(A_ThisHotkey, 0, 1)) - g_FirstChar + 1

    if (g_CurrentCommandList[index] != "")
    {
        ChangeCommand(index - 1, true)
    }
return

ChangeCommand(step, resetCurrentLine = false)
{
    ControlGetText, g_CurrentInput, %g_InputArea%

    if (resetCurrentLine
        || (SubStr(g_CurrentInput, 1, 1) != "@" && SubStr(g_CurrentInput, 1, 2) != "|@"))
    {
        g_CurrentLine := 1
    }

    row := g_CurrentCommandList.Length()
    if (row > g_DisplayRows)
    {
        row := g_DisplayRows
    }

    g_CurrentLine := Mod(g_CurrentLine + step, row)
    if (g_CurrentLine == 0)
    {
        g_CurrentLine := row
    }

    ; 重置当前命令
    g_CurrentCommand := g_CurrentCommandList[g_CurrentLine]

    ; 修改输入框内容
    currentChar := Chr(g_FirstChar + g_CurrentLine - 1)
    if (SubStr(g_CurrentInput, 1, 1) == "|")
    {
        newInput := "|@" currentChar " "
    }
    else
    {
        newInput := "@" currentChar " "
    }

    if (g_UseFallbackCommands)
    {
        if (SubStr(g_CurrentInput, 1, 1) == "@")
        {
            newInput .= SubStr(g_CurrentInput, 4)
        }
        else
        {
            newInput .= g_CurrentInput
        }
    }

    ControlGetText, result, %g_DisplayArea%
    result := StrReplace(result, ">| ", " | ")
    if (currentChar == Chr(g_FirstChar))
    {
        result := currentChar ">" SubStr(result, 3)
    }
    else
    {
        result := StrReplace(result, "`r`n" currentChar " | ", "`r`n" currentChar ">| ")
    }

    DisplaySearchResult(result)

    ControlSetText, %g_InputArea%, %newInput%, %g_WindowName%
    Send, {end}
}

GuiClose()
{
    if (!g_Conf.Config.RunInBackground)
    {
        GoSub, ExitRunZ
    }
}

SaveAutoConf()
{
    if (g_Conf.Config.SaveInputText)
    {
        g_AutoConf.DeleteKey("Auto", "InputText")
        g_AutoConf.AddKey("Auto", "InputText", g_CurrentInput)
    }

    if (g_Conf.Config.SaveHistory)
    {
        g_AutoConf.DeleteSection("History")
        g_AutoConf.AddSection("History")

        for index, element in g_HistoryCommands
        {
            if (element != "")
            {
                g_AutoConf.AddKey("History", index, element)
            }
        }
    }

    Loop
    {
        g_AutoConf.Save()

        if (!FileExist(g_AutoConfFile))
        {
            MsgBox, 配置文件 %g_AutoConfFile% 写入后丢失，请检查磁盘并点确定来重试
        }
        else
        {
            break
        }
    }
}

ExitRunZ:
    SaveAutoConf()
    ExitApp
return

GenerateSearchFileList()
{
    FileDelete, %g_SearchFileList%

    searchFileType := g_Conf.Config.SearchFileType

    for dirIndex, dir in StrSplit(g_Conf.Config.SearchFileDir, " | ")
    {
        if (InStr(dir, "A_") == 1)
        {
            searchPath := %dir%
        }
        else
        {
            searchPath := dir
        }

        for extIndex, ext in StrSplit(searchFileType, " | ")
        {
            Loop, Files, %searchPath%\%ext%, R
            {
                if (g_Conf.Config.SearchFileExclude != ""
                        && RegExMatch(A_LoopFileLongPath, g_Conf.Config.SearchFileExclude))
                {
                    continue
                }
                FileAppend, file | %A_LoopFileLongPath%`n, %g_SearchFileList%,
            }
        }
    }
}

ReindexFiles:
    if (WinActive(g_WindowName))
    {
        ToolTip, 正在重建索引，请稍后...
    }

    GenerateSearchFileList()

    GoSub, CleanupRank

    if (WinActive(g_WindowName))
    {
        ToolTip, 重建索引完毕
        SetTimer, RemoveToolTip, 800
    }
return

EditConfig:
    if (g_Conf.Config.Editor != "")
    {
        Run, % g_Conf.Config.Editor " """ g_ConfFile """"
    }
    else
    {
        Run, % g_ConfFile
    }
return

EditAutoConfig:
    if (g_Conf.Config.Editor != "")
    {
        Run, % g_Conf.Config.Editor " """ g_AutoConfFile """"
    }
    else
    {
        Run, % g_AutoConfFile
    }
return


ProcessInputCommand:
    ControlGetText, g_CurrentInput, %g_InputArea%
    ; https://github.com/goreliu/runz/issues/40
    ; 但如果改了这个，快速输入的话，搜索结果可能不更新
    ;GoSub, ProcessInputCommandCallBack
    ;return

    ; 如果使用异步的方式，TurnOnResultFilter 后会出问题，先绕一下
    if (SubStr(g_CurrentInput, 0, 1) == " ")
    {
        GoSub, ProcessInputCommandCallBack
        return
    }

    ; 为了避免搜索时间过长导致不再调用 ProcessInputCommand
    ; 不清楚这样做是否有其他问题
    SetTimer, ProcessInputCommandCallBack, 0
return

ProcessInputCommandCallBack:
    SetTimer, ProcessInputCommandCallBack, Off

    if (g_SkinConf.ShowInputBoxOnlyIfEmpty)
    {
        if (g_CurrentInput != "")
        {
            if (g_SkinConf.ShowCurrentCommand)
            {
                windowHeight := g_SkinConf.BorderSize * 4
                    + g_SkinConf.EditHeight * 2 + g_SkinConf.DisplayAreaHeight
            }
            else
            {
                windowHeight := g_SkinConf.BorderSize * 3
                    + g_SkinConf.EditHeight + g_SkinConf.DisplayAreaHeight
            }
            WinMove, %g_WindowName%, , , , , %windowHeight%
        }
        else
        {
            windowHeight := g_SkinConf.BorderSize * 2 + g_SkinConf.EditHeight
            WinMove, %g_WindowName%, , , , , %windowHeight%
        }

        if (g_SkinConf.RoundCorner > 0)
        {
            WinSet, Region, % "0-0 w" border * 2 + g_SkinConf.WidgetWidth " h" windowHeight
                . " r" g_SkinConf.RoundCorner "-" g_SkinConf.RoundCorner, % g_WindowName
        }
    }

    SearchCommand(g_CurrentInput)
return

SearchCommand(command = "", firstRun = false)
{
    g_UseDisplay := false
    g_ExecInterval := -1
    result := ""
    ; 供去重使用
    fullResult := ""
    static resultToFilter := ""
    commandPrefix := SubStr(command, 1, 1)

    if (commandPrefix == ";" || commandPrefix == ":")
    {
        g_UseResultFilter := false
        g_UseRealtimeExec := false
        resultToFilter := ""
        g_PipeArg := ""

        if (commandPrefix == ";")
        {
            g_CurrentCommand := g_FallbackCommands[1]
        }
        else if (commandPrefix == ":")
        {
            g_CurrentCommand := g_FallbackCommands[2]
        }

        g_CurrentCommandList := Object()
        g_CurrentCommandList.Push(g_CurrentCommand)
        result .= Chr(g_FirstChar) ">| "
            . StrReplace(g_CurrentCommand, "function | ", "功能 | ")
        DisplaySearchResult(result)
        return result
    }
    else if (commandPrefix == "|" && Arg != "")
    {
        ; 记录管道参数
        if (g_PipeArg == "")
        {
            g_PipeArg := Arg
        }
        ; 去掉 |，然后按常规搜索处理
        command := SubStr(command, 2)
        if (SubStr(command, 1, 1) == "@")
        {
            command := SubStr(command, 1, 4)
            return
        }
    }
    else if (InStr(command, " ") && g_CurrentCommand != "")
    {
        g_PipeArg := ""

        ; 输入包含空格时锁定搜索结果

        if (g_UseResultFilter)
        {
            if (resultToFilter == "")
            {
                ControlGetText, resultToFilter, %g_DisplayArea%
            }

            ; 取出空格后边的参数
            needle := SubStr(g_CurrentInput, InStr(g_CurrentInput, " ") + 1)
            DisplayResult(FilterResult(resultToFilter, needle))
        }
        else if (g_UseRealtimeExec)
        {
            RunCommand(g_CurrentCommand)
            resultToFilter := ""
        }
        else
        {
            resultToFilter := ""
        }

        return
    }
    else if (commandPrefix == "@")
    {
        g_UseResultFilter := false
        g_UseRealtimeExec := false
        resultToFilter := ""

        ; 搜索结果被锁定，直接退出
        return
    }

    g_UseResultFilter := false
    g_UseRealtimeExec := false
    resultToFilter := ""

    if (commandPrefix != "|")
    {
        g_PipeArg := ""
    }

    g_CurrentCommandList := Object()

    order := g_FirstChar

    for index, element in g_Commands
    {
        if (InStr(fullResult, element "`n") || inStr(g_ExcludedCommands, element "`n"))
        {
            continue
        }

        splitedElement := StrSplit(element, " | ")

        if (splitedElement[1] == "file")
        {
            SplitPath, % splitedElement[2], fileName, fileDir, , fileNameNoExt

            ; 只搜索和展示不带扩展名的文件名
            elementToSearch := fileNameNoExt
            if (g_Conf.Config.ShowFileExt)
            {
                elementToShow := "file | " . fileName " | " splitedElement[3]
            }
            else
            {
                elementToShow := "file | " . fileNameNoExt " | " splitedElement[3]
            }


            if (splitedElement.Length() >= 3)
            {
                elementToSearch .= " " . splitedElement[3]
            }

            if (g_Conf.Config.SearchFullPath)
            {
                ; TCMatch 在搜索路径时只搜索文件名，强行将 \ 转成空格
                elementToSearch := StrReplace(fileDir, "\", " ") . " " . elementToSearch
            }
        }
        else
        {
            elementToShow := splitedElement[1] " | " splitedElement[2]
            elementToSearch := StrReplace(splitedElement[2], "/", " ")
            elementToSearch := StrReplace(elementToSearch, "\", " ")

            if (splitedElement.Length() >= 3)
            {
                elementToShow .= " | " splitedElement[3]
                elementToSearch .= " " . splitedElement[3]
            }
        }

        if (command == "" || MatchCommand(elementToSearch, command))
        {
            fullResult .= element "`n"
            g_CurrentCommandList.Push(element)

            if (order == g_FirstChar)
            {
                g_CurrentCommand := element
                result .= Chr(order++) . ">| " . elementToShow
            }
            else
            {
                result .= "`n" Chr(order++) . " | " . elementToShow
            }

            if (order - g_FirstChar >= g_DisplayRows)
            {
                break
            }
            ; 第一次运行只加载 function 类型
            if (firstRun && (order - g_FirstChar >= g_DisplayRows - 4))
            {
                result .= "`n`n现有 " g_Commands.Length() " 条搜索项。"
                result .= "`n`n键入内容 搜索，回车 执行当前命令，Alt + 字母 执行，F1 帮助，Esc 关闭。"

                break
            }
        }
    }

    if (result == "")
    {
        if (IsLabel("Calc") && Eval(g_CurrentInput) != 0)
        {
            DisplayResult(Eval(g_CurrentInput))
            return
        }

        g_UseFallbackCommands := true
        g_CurrentCommand := g_FallbackCommands[1]
        g_CurrentCommandList := g_FallbackCommands

        for index, element in g_FallbackCommands
        {
            if (index == 1)
            {
                result .= Chr(g_FirstChar - 1 + index++) . ">| " element
            }
            else
            {
                result .= "`n"
                result .= Chr(g_FirstChar - 1 + index++) . " | " element
            }
        }
    }
    else
    {
        g_UseFallbackCommands := false
    }

    if (g_SkinConf.HideCol2)
    {
        result := StrReplace(result, "file | ")
        result := StrReplace(result, "function | ")
        result := StrReplace(result, "cmd | ")
        result := StrReplace(result, "url | ")
    }
    else
    {
        result := StrReplace(result, "file | ", "文件 | ")
        result := StrReplace(result, "function | ", "功能 | ")
        result := StrReplace(result, "cmd | ", "命令 | ")
        result := StrReplace(result, "url | ", "网址 | ")
    }

    DisplaySearchResult(result)
    return result
}

DisplaySearchResult(result)
{
    DisplayControlText(result)

    if (g_CurrentCommandList.Length() == 1 && g_Conf.Config.RunIfOnlyOne)
    {
        RunCommand(g_CurrentCommand)
    }

    if (g_SkinConf.ShowCurrentCommand)
    {
        commandToShow := SubStr(g_CurrentCommand, InStr(g_CurrentCommand, " | ") + 3)
        ControlSetText, %g_CommandArea%, %commandToShow%, %g_WindowName%
    }
}

FilterResult(text, needle)
{
    result := ""
    Loop, Parse, text, `n, `r
    {
        if (!InStr(A_LoopField, " | ") && MatchResult(A_LoopField, needle))
        {
            result .= A_LoopField "`n"
        }
        else if (MatchResult(StrReplace(SubStr(A_LoopField, 5), "\", " "), needle))
        {
            result .= A_LoopField "`n"
        }
    }

    return result
}

TurnOnResultFilter()
{
    if (!g_UseResultFilter)
    {
        g_UseResultFilter := true

        if (!InStr(g_CurrentInput, " "))
        {
            ControlFocus, %g_InputArea%
            Send, {space}
        }
    }
}

TurnOnRealtimeExec()
{
    if (!g_UseRealtimeExec)
    {
        g_UseRealtimeExec := true

        if (!InStr(g_CurrentInput, " "))
        {
            ControlFocus, %g_InputArea%
            Send, {space}
        }
    }
}

SetExecInterval(second)
{
    ; g_ExecInterval 为 0 时，表示可以进入间隔运行状态
    ; g_ExecInterval 为 -1 时，表示状态以被打破，需要退出
    if (g_ExecInterval >= 0)
    {
        g_ExecInterval := second * 1000
        return true
    }
    else
    {
        SetTimer, %g_LastExecLabel%, Off
        return false
    }
}

ClearInput:
    ClearInput()
return

; 给插件用的函数
ClearInput()
{
    ControlSetText, %g_InputArea%, , %g_WindowName%
    ControlFocus, %g_InputArea%
}

RunCurrentCommand:
    RunCommand(g_CurrentCommand)
return

ParseArg:
    if (g_PipeArg != "")
    {
        Arg := g_PipeArg
        return
    }

    commandPrefix := SubStr(g_CurrentInput, 1, 1)

    ; 分号或者冒号的情况，直接取命令为参数
    if (commandPrefix == ";" || commandPrefix == ":")
    {
        Arg := SubStr(g_CurrentInput, 2)
        return
    }
    else if (commandPrefix == "@")
    {
        ; 处理调整过顺序的命令
        Arg := SubStr(g_CurrentInput, 4)
        return
    }

    ; 用空格来判断参数
    if (InStr(g_CurrentInput, " ") && !g_UseFallbackCommands)
    {
        Arg := SubStr(g_CurrentInput, InStr(g_CurrentInput, " ") + 1)
    }
    else if (g_UseFallbackCommands)
    {
        Arg := g_CurrentInput
    }
    else
    {
        Arg := ""
    }
return

MatchCommand(Haystack, Needle)
{
    if (g_EnableTCMatch)
    {
        return TCMatch(Haystack, Needle)
    }

    return InStr(Haystack, Needle)
}

MatchResult(Haystack, Needle)
{
    if (g_EnableTCMatch)
    {
        return TCMatch(Haystack, Needle)
    }

    return InStr(Haystack, Needle)
}

RunCommand(originCmd)
{
    GoSub, ParseArg

    g_UseDisplay := false
    g_DisableAutoExit := true
    g_ExecInterval := 0

    splitedOriginCmd := StrSplit(originCmd, " | ")
    cmd := splitedOriginCmd[2]

    if (splitedOriginCmd[1] == "file")
    {
        if (InStr(cmd, ".lnk"))
        {
            ; 处理 32 位 ahk 运行不了某些 64 位系统 .lnk 的问题
            FileGetShortcut, %cmd%, filePath
            if (!FileExist(filePath))
            {
                filePath := StrReplace(filePath, "C:\Program Files (x86)", "C:\Program Files")
                if (FileExist(filePath))
                {
                    cmd := filePath
                }
            }
        }

        SplitPath, cmd, , fileDir, ,

        if (Arg == "")
        {
            Run, %cmd%, %fileDir%
        }
        else
        {
            Run, %cmd% "%Arg%", %fileDir%
        }
    }
    else if (splitedOriginCmd[1] == "function")
    {
        ; 第四个参数是参数
        if (splitedOriginCmd.Length() >= 4)
        {
            Arg := splitedOriginCmd[4]
        }

        if (IsLabel(cmd))
        {
            GoSub, %cmd%
        }
    }
    else if (splitedOriginCmd[1] == "cmd")
    {
        RunWithCmd(cmd)
    }
    else if (splitedOriginCmd[1] == "url")
    {
        url := splitedOriginCmd[2]
        if (!Instr(url, "http"))
        {
            url := "http://" . url
        }

        Run, %url%
    }

    if (g_Conf.Config.SaveHistory && cmd != "DisplayHistoryCommands")
    {
        if (splitedOriginCmd.Length() == 3 && Arg != "")
        {
            g_HistoryCommands.InsertAt(1, originCmd " | " Arg)
        }
        else if (originCmd != "")
        {
            g_HistoryCommands.InsertAt(1, originCmd)
        }

        if (g_HistoryCommands.Length() > g_Conf.Config.HistorySize)
        {
            g_HistoryCommands.Pop()
        }
    }

    if (g_Conf.Config.AutoRank)
    {
        ChangeRank(originCmd)
    }

    g_DisableAutoExit := false

    if (g_Conf.Config.RunOnce && !g_UseDisplay)
    {
        if (!g_Conf.Config.KeepInputText)
        {
            GoSub, ClearInput
        }
        GoSub, HideOrExit
    }

    if (g_ExecInterval > 0 && splitedOriginCmd[1] == "function")
    {
        SetTimer, %cmd%, %g_ExecInterval%
        g_LastExecLabel := cmd
    }

    g_PipeArg := ""
    FullPipeArg := ""
}

ChangeRank(cmd, show = false, inc := 1)
{
    splitedCmd := StrSplit(cmd, " | ")

    if (splitedCmd.Length() >= 4 && splitedCmd[1] == "function")
    {
        ; 去掉参数
        cmd := splitedCmd[1]  " | " splitedCmd[2] " | " splitedCmd[3]
    }

    cmdRank := g_AutoConf.GetValue("Rank", cmd)
    if cmdRank is integer
    {
        g_AutoConf.DeleteKey("Rank", cmd)
        cmdRank += inc
    }
    else
    {
        cmdRank := inc
    }

    if (cmdRank != 0 && cmd != "")
    {
        ; 如果将到负数，都设置成 -1，然后屏蔽
        if (cmdRank < 0)
        {
            cmdRank := -1
            g_ExcludedCommands .= cmd "`n"
        }

        g_AutoConf.AddKey("Rank", cmd, cmdRank)
    }
    else
    {
        cmdRank := 0
    }

    if (show)
    {
        ToolTip, 调整 %cmd% 的权重到 %cmdRank%
        SetTimer, RemoveToolTip, 800
    }
}

; 比较耗时，必要时才使用，也可以手动编辑 RunZ.auto.ini
CleanupRank:
    ; 先把 g_Commands 里的 Rank 信息清掉
    LoadFiles(false)

    for command, rank in g_AutoConf.Rank
    {
        cleanup := true
        for index, element in g_Commands
        {
            if (InStr(element, command) == 1)
            {
                cleanup := false
                break
            }
        }
        if (cleanup)
        {
            g_AutoConf.DeleteKey("Rank", command)
        }
    }

    Loop
    {
        g_AutoConf.Save()

        if (!FileExist(g_AutoConfFile))
        {
            MsgBox, 配置文件 %g_AutoConfFile% 写入后丢失，请检查磁盘并点确定来重试
        }
        else
        {
            break
        }
    }

    LoadFiles()
return

RunSelectedCommand:
    if (SubStr(A_ThisHotkey, 1, 1) == "~")
    {
        ControlGetFocus, ctrl,
        if (ctrl == g_InputArea)
        {
            return
        }
    }

    index := Asc(SubStr(A_ThisHotkey, 0, 1)) - g_FirstChar + 1

    RunCommand(g_CurrentCommandList[index])
return

IncreaseRank:
    if (g_CurrentCommand != "")
    {
        ChangeRank(g_CurrentCommand, true)
        LoadFiles()
    }
return

DecreaseRank:
    if (g_CurrentCommand != "")
    {
        ChangeRank(g_CurrentCommand, true, -1)
        LoadFiles()
    }
return

LoadFiles(loadRank := true)
{
    g_Commands := Object()
    g_FallbackCommands := Object()

    if (loadRank)
    {
        rankString := ""
        for command, rank in g_AutoConf.Rank
        {
            if (StrLen(command) > 0)
            {
                if (rank >= 1)
                {
                    rankString .= rank "`t" command "`n"
                }
                else
                {
                    g_ExcludedCommands .= command "`n"
                }
            }
        }

        if (rankString != "")
        {
            Sort, rankString, R N

            Loop, Parse, rankString, `n
            {
                if (A_LoopField == "")
                {
                    continue
                }

                g_Commands.Push(StrSplit(A_LoopField, "`t")[2])
            }
        }
    }


    for key, value in g_Conf.Command
    {
        if (value != "")
        {
            g_Commands.Push(key . " | " . value)
        }
        else
        {
            g_Commands.Push(key)
        }
    }

    for index, element in g_Plugins
    {
        if (IsLabel(element))
        {
            GoSub, %element%
        }
        else
        {
            MsgBox, 未在 %A_ScriptDir%\Plugins\%element%.ahk 中发现 %element% 标签，请修改！
        }
    }

    g_FallbackCommands := Object()
    for key, value in g_Conf.FallbackCommand
    {
        if (IsLabel(StrSplit(key, " | ")[2]))
        {
            g_FallbackCommands.Push(key)
        }
    }

    if (g_FallbackCommands.Length() == 0)
    {
        g_FallbackCommands.Push("function | AhkRun | 使用 Ahk 的 Run() 运行")
    }

    if (FileExist(A_ScriptDir "\Conf\UserFunctionsAuto.txt"))
    {
        userFunctionLabel := "UserFunctionsAuto"
        if (IsLabel(userFunctionLabel))
        {
            GoSub, %userFunctionLabel%
        }
        else
        {
            MsgBox, 未在 %A_ScriptDir%\Conf\UserFunctionsAuto.txt 中发现 %userFunctionLabel% 标签，请修改！
        }
    }

    if (FileExist(g_UserFileList))
    {
        Loop, Read, %g_UserFileList%
        {
            g_Commands.Push(A_LoopReadLine)
        }
    }

    Loop, Read, %g_SearchFileList%
    {
        g_Commands.Push(A_LoopReadLine)
    }

    if (g_Conf.Config.LoadControlPanelFunctions)
    {
        Loop, Read, %A_ScriptDir%\Core\ControlPanelFunctions.txt
        {
            g_Commands.Push(A_LoopReadLine)
        }
    }
}

; 用来显示控制界面
DisplayControlText(text)
{
    ControlSetText, %g_DisplayArea%, % AlignText(text), %g_WindowName%
}

; 用来显示命令结果
DisplayResult(result := "")
{
    textToDisplay := StrReplace(result, "`n", "`r`n")
    ControlSetText, %g_DisplayArea%, %textToDisplay%, %g_WindowName%
    g_UseDisplay := true
    result := ""
    textToDisplay := ""
}

LoadHistoryCommands()
{
    historySize := g_Conf.Config.HistorySize

    index := 0
    for key, value in g_AutoConf.History
    {
        if (StrLen(value) > 0)
        {
            g_HistoryCommands.Push(value)
            index++

            if (index == historySize)
            {
                return
            }
        }
    }
}

DisplayHistoryCommands:
    g_UseDisplay := false
    result := ""
    g_CurrentCommandList := Object()
    g_CurrentLine := 1

    for index, element in g_HistoryCommands
    {
        if (index == 1)
        {
            result .= Chr(g_FirstChar + index - 1) . ">| "
            g_CurrentCommand := element
        }
        else
        {
            result .= Chr(g_FirstChar + index - 1) . " | "
        }

        splitedElement := StrSplit(element, " | ")

        result .= splitedElement[1] " | " splitedElement[2]
            . " | " splitedElement[3] " #参数： " splitedElement[4] "`n"

        g_CurrentCommandList.Push(element)
    }

    result := StrReplace(result, "file | ", "文件 | ")
    result := StrReplace(result, "function | ", "功能 | ")
    result := StrReplace(result, "cmd | ", "命令 | ")
    result := StrReplace(result, "url | ", "网址 | ")

    DisplayControlText(result)
return

; 第三个参数不再是 fallback，备用，为了兼容不改变第四个参数的含义
@(label, info, fallback = false, key = "")
{
    if (!IsLabel(label))
    {
        MsgBox, 未找到 %label% 标签，请检查 %A_ScriptDir%\Conf\UserFunctions.ahk 文件格式！
        return
    }

    g_Commands.Push("function | " . label . " | " . info )

    if (key != "")
    {
        Hotkey, %key%, %label%
    }
}

RunAndGetOutput(command)
{
    tempFileName := "RunZ.stdout.log"
    fullCommand = %ComSpec% /C "%command% > %tempFileName%"

    /*
    fullCommand = bash -c "%command% &> %tempFileName%"

    if (!FileExist("c:\msys64\usr\bin\bash.exe"))
    {
        fullCommand = %ComSpec% /C "%command% > %tempFileName%"
    }
    */

    RunWait, %fullCommand%, %A_Temp%, Hide
    FileRead, result, %A_Temp%\%tempFileName%
    FileDelete, %A_Temp%\%tempFileName%
    return result
}

RunWithCmd(command, onlyCmd = false)
{
    if (!onlyCmd && FileExist("c:\msys64\usr\bin\mintty.exe"))
    {
        Run, % "mintty -e sh -c '" command "; read'"
    }
    else
    {
        Run, % ComSpec " /C " command " & pause"
    }
}

OpenPath(filePath)
{
    if (!FileExist(filePath))
    {
        return
    }

    if (FileExist(g_Conf.Config.TCPath))
    {
        TCPath := g_Conf.Config.TCPath
        Run, %TCPath% /O /A /L="%filePath%"
    }
    else
    {
        SplitPath, filePath, , fileDir, ,
        Run, explorer "%fileDir%"
    }
}

GetAllFunctions()
{
    result := ""

    for index, element in g_Commands
    {
        if (InStr(element, "function | ") == 1 and !InStr(result, element "`n"))
        {
            result .= "* | " element "`n"
        }
    }

    result := StrReplace(result, "function | ", "功能 | ")

    return AlignText(result)
}

OpenCurrentFileDir:
    filePath := StrSplit(g_CurrentCommand, " | ")[2]
    OpenPath(filePath)
return

DeleteCurrentFile:
    filePath := StrSplit(g_CurrentCommand, " | ")[2]

    if (!FileExist(filePath))
    {
        return
    }

    FileRecycle, % filePath
    GoSub, ReindexFiles
return

ShowCurrentFile:
    clipboard := StrSplit(g_CurrentCommand, " | ")[2]
    ToolTip, % clipboard
    SetTimer, RemoveToolTip, 800
return

RemoveToolTip:
    ToolTip
    SetTimer, RemoveToolTip, Off
return


WM_MOUSEMOVE(wParam, lParam)
{
    if (wparam = 1) ; LButton
    {
        PostMessage, 0xA1, 2, , , A ; WM_NCLBUTTONDOWN
    }

    if (!g_Conf.Config.ChangeCommandOnMouseMove)
    {
        return
    }

    MouseGetPos, , mouseY, , classnn,
    if (classnn != g_DisplayArea)
    {
        return -1
    }

    ControlGetPos, , y, , h, %g_DisplayArea%
    lineHeight := h / g_DisplayRows
    index := Ceil((mouseY - y) / lineHeight)

    if (g_CurrentCommandList[index] != "")
    {
        ChangeCommand(index - 1, true)
    }
}

WM_ACTIVATE(wParam, lParam)
{
    if (g_DisableAutoExit)
    {
        return
    }

    if (wParam >= 1) ; 窗口激活
    {
        return
    }
    else if (wParam <= 0) ; 窗口非激活
    {
        ; 这样有可能第一次显示主界面时，窗口失去焦点后不关闭
        ; 暂时没有好的解决方法，如果改用 SetTimer 调用，会导致用快捷键显示主窗口失败

		if (!WinExist("RunZ.ahk"))
		{
			if (!g_Conf.Config.KeepInputText)
			{
				ControlSetText, %g_InputArea%, , %g_WindowName%
			}

			GoSub, HideOrExit
		}
    }
}

KeyHelpText()
{
    return AlignText(""
    . "* | 按键 | Shift + F1 | 显示置顶的按键提示`n"
    . "* | 按键 | Alt + F4   | 退出置顶的按键提示`n"
    . "* | 按键 | 回车       | 执行当前命令`n"
    . "* | 按键 | Esc        | 关闭窗口`n"
    . "* | 按键 | Alt +      | 加每列行首字符执行`n"
    . "* | 按键 | Tab +      | 再按每列行首字符执行`n"
    . "* | 按键 | Tab +      | 再按 Shift + 行首字符 定位`n"
    . "* | 按键 | Win  + j   | 显示或隐藏窗口`n"
    . "* | 按键 | Ctrl + j   | 移动到下一条命令`n"
    . "* | 按键 | Ctrl + k   | 移动到上一条命令`n"
    . "* | 按键 | Ctrl + f   | 在输出结果中翻到下一页`n"
    . "* | 按键 | Ctrl + b   | 在输出结果中翻到上一页`n"
    . "* | 按键 | Ctrl + h   | 显示历史记录`n"
    . "* | 按键 | Ctrl + n   | 可增加当前功能的权重`n"
    . "* | 按键 | Ctrl + p   | 可减少当前功能的权重`n"
    . "* | 按键 | Ctrl + l   | 清除编辑框内容`n"
    . "* | 按键 | Ctrl + r   | 重新创建待搜索文件列表`n"
    . "* | 按键 | Ctrl + q   | 重启`n"
    . "* | 按键 | Ctrl + d   | 用 TC 打开第一个文件所在目录`n"
    . "* | 按键 | Ctrl + s   | 显示并复制当前文件的完整路径`n"
    . "* | 按键 | Ctrl + x   | 删除当前文件`n"
    . "* | 按键 | Ctrl + i   | 移动光标当行首`n"
    . "* | 按键 | Ctrl + o   | 移动光标当行尾`n"
    . "* | 按键 | F2         | 编辑配置文件`n"
    . "* | 按键 | F3         | 编辑自动写入的配置文件`n"
    . "* | 功能 | 输入网址   | 可直接输入 www 或 http 开头的网址`n"
    . "* | 功能 | `;         | 以分号开头命令，用 ahk 运行`n"
    . "* | 功能 | :          | 以冒号开头的命令，用 cmd 运行`n"
    . "* | 功能 | 无结果     | 搜索无结果，回车用 ahk 运行`n"
    . "* | 功能 | 空格       | 输入空格后，搜索内容锁定")
}

UpdateSendTo(create = true, overwrite = false)
{
    lnkFilePath := StrReplace(A_StartMenu, "\Start Menu", "\SendTo\") "RunZ.lnk"

    if (!create)
    {
        FileDelete, %lnkFilePath%
        return
    }

    if (!overwrite && FileExist(lnkFilePath))
    {
        return
    }

    FileCreateShortcut, % A_ScriptDir "\RunZ.exe", % A_ScriptDir "\Core\SendToRunZ.lnk"
        , , "%A_ScriptDir%\Core\RunZCmdTool.ahk", 发送到 RunZ, % A_ScriptDir "\RunZ.ico"
    FileCopy, % A_ScriptDir "\Core\SendToRunZ.lnk"
        , % StrReplace(A_StartMenu, "\Start Menu", "\SendTo\") "RunZ.lnk", 1
}

UpdateStartupLnk(create = true, overwrite = false)
{
    lnkFilePath := A_Startup "\RunZ.lnk"

    if (!create)
    {
        FileDelete, %lnkFilePath%
        return
    }

    if (!FileExist(lnkFilePath) || overwrite)
    {
        FileCreateShortcut, % A_ScriptDir "\RunZ.exe", %lnkFilePath%
            , %A_ScriptDir%, RunZ.ahk --hide, RunZ, % A_ScriptDir "\RunZ.ico"
    }
}

ChangePath:
    UpdateSendTo(g_Conf.Config.CreateSendToLnk, true)
    UpdateStartupLnk(g_Conf.Config.CreateStartupLnk, true)
return

AlignText(text)
{
    col3MaxLen := g_SkinConf.DisplayCol3MaxLength
    col4MaxLen := g_SkinConf.DisplayCol4MaxLength
    col3Pos := 10

    StrSpace := " "
    Loop, % col3MaxLen + col4MaxLen
        StrSpace .= " "

    result := ""

    if (g_SkinConf.HideCol2)
    {
        ; 隐藏第二列的话，把第二列的空间分给第三列
        col3MaxLen += 7
        col3Pos := 5

        hasCol2 := true
        Loop, Parse, text, `n, `r
        {
            if (SubStr(text, 3, 1) != "|" || SubStr(text, 8, 1) != "|")
            {
                hasCol2 := false
                break
            }
        }

        if (hasCol2)
        {
            col3Pos := 10
        }
    }

    if (g_SkinConf.HideCol4IfEmpty)
    {
        Loop, Parse, text, `n, `r
        {
            if (StrSplit(SubStr(A_LoopField, col3Pos), " | ")[2] != "")
            {
                hasCol4 := true
                break
            }
        }

        if (!hasCol4)
        {
            ; 加上中间的 " | "
            col3MaxLen += col4MaxLen + 3
            col4MaxLen := 0
        }
    }

    Loop, Parse, text, `n, `r
    {
        if (!InStr(A_LoopField, " | "))
        {
            result .= A_LoopField "`r`n"
            continue
        }

        if (hasCol2)
        {
            ; 内容包含第二列，需要去掉
            result .= SubStr(A_LoopField, 1, 4)
        }
        else
        {
            result .= SubStr(A_LoopField, 1, col3Pos - 1)
        }

        splitedLine := StrSplit(SubStr(A_LoopField, col3Pos), " | ")
        col3RealLen := StrLen(RegExReplace(splitedLine[1], "[^\x00-\xff]", "`t`t"))

        if (col3RealLen > col3MaxLen)
        {
            result .= SubStrByByte(splitedLine[1], col3MaxLen)
        }
        else
        {
            result .= splitedLine[1] . SubStr(StrSpace, 1, col3MaxLen - col3RealLen)
        }

        if (col4MaxLen > 0)
        {
            result .= " | "

            col4RealLen := StrLen(RegExReplace(splitedLine[2], "[^\x00-\xff]", "`t`t"))

            if (col4RealLen > col4MaxLen)
            {
                result .= SubStrByByte(splitedLine[2], col4MaxLen)
            }
            else
            {
                result .= splitedLine[2]
            }
        }

        result .= "`r`n"
    }

    return result
}

WatchUserFileList:
    FileGetTime, newUserFileListModifyTime, %g_UserFileList%
    if (newUserFileListModifyTime == "")
    {
        FileAppend, , %g_UserFileList%
    }

    if (lastUserFileListModifyTime != "" && lastUserFileListModifyTime != newUserFileListModifyTime)
    {
        LoadFiles()
    }
    lastUserFileListModifyTime := newUserFileListModifyTime

    FileGetTime, newConfFileModifyTime, %g_ConfFile%
    if (lastConfFileModifyTime != "" && lastConfFileModifyTime != newConfFileModifyTime)
    {
        GoSub, RestartRunZ
    }
    lastConfFileModifyTime := newConfFileModifyTime
return

SaveResultAsArg:
    Arg := ""
    ControlGetText, result, %g_DisplayArea%

    ; 处理隐藏第二列的情况
    if (g_SkinConf.HideCol2)
    {
        FullPipeArg := ""
        Loop, Parse, result, `n, `r
        {
            FullPipeArg .= SubStr(A_LoopField, 1, 2) "| 占位 | " SubStr(A_LoopField, 5) "`n"
        }
    }
    else
    {
        FullPipeArg := result
    }

    if (InStr(g_CurrentCommand, "file | ") == 1)
    {
        Arg .= StrSplit(g_CurrentCommand, " | ")[2]
    }
    else if (!InStr(result, " | "))
    {
        Arg .= StrReplace(result, "`n", " ")
        Arg := StrReplace(Arg, "`r")
    }
    else
    {
        if (g_SkinConf.HideCol2)
        {
            Loop, Parse, result, `n, `r
            {
                Arg .= Trim(StrSplit(A_LoopField, " | ")[2]) " "
            }
        }
        else
        {
            Loop, Parse, result, `n, `r
            {
                Arg .= Trim(StrSplit(A_LoopField, " | ")[3]) " "
            }
        }
    }

    Arg := Trim(Arg)

    ControlFocus, %g_InputArea%
    ControlSetText, %g_InputArea%, |
    Send, {End}
    if (g_CommandFilter != "")
    {
        ; 第一个 | 代表要用管道执行，不然 g_PipeArg 会被清空
        SearchCommand("|" g_CommandFilter)
        g_CommandFilter := ""
    }
return

; 格式：
; 与 command1&command2
; 或 command1|command2
; 非 !command1
SetCommandFilter(command)
{
    g_CommandFilter := command
}

Help:
    DisplayResult(KeyHelpText() . GetAllFunctions())
return

KeyHelp:
    ToolTip, % KeyHelpText()
    SetTimer, RemoveToolTip, 5000
return


#include %A_ScriptDir%\Lib\EasyIni.ahk
#include %A_ScriptDir%\Lib\TCMatch.ahk
#include %A_ScriptDir%\Core\Common.ahk
#include *i %A_ScriptDir%\Core\Plugins.ahk
; 发送到菜单自动生成的命令
#include *i %A_ScriptDir%\Conf\UserFunctionsAuto.txt


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;第二段自定义部分开始
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 1.2. 局部热字母/热键
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;将单侧标点符号，自动输入为双侧标点符号
;[::wrapContent("[","]")
;(::wrapContent("(",")")
;<::wrapContent("<",">")
;{::wrapContent("{","}")

;;;在开发工具内全部使用英文标点
;;; ["。","."],["，",","],["；",";"],["（","("],["）",")"]

; :*:.::{text}.
; :*:,::{text},
; :*:;::{text};
; :*:"::{text}"
; :*:'::{text}'
; :*:<::{text}<
; :*:>::{text}>
; :*:(::{text}(
; :*:)::{text})
;;;:*:、::{text}/



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 1.2. 局部热字母/热键(结束)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#IfWinActivet

;;;将esc的单击默认原来的操作；双击设置为关闭tab; 三击设置为应用程序。
~esc:: 
	PressKeyManyTimes("","press_2_esc_event4common","press_3_esc_event4common",500)		
	return

	press_2_esc_event4common()
	{
		;;暂时不使用ctrl+w键
		;;Send,^w
		;;目前大部分应用都支持ctrl+f4
		Send,^{f4}
	}

	press_3_esc_event4common()
	{
		;;暂时不使用ctrl+w键
		;;Send,^w
		;;目前大部分应用都支持ctrl+f4
		Send,!{f4}
	}

;;;;退出当前ahk应用程序（慎用）
;esc::exitapp

;;显示当前AHK的版本号
~LButton & v::
    Msgbox, AHK的版本为:%A_AhkVersion%
return

;;;使用PrtSc按键调用搜狗输入法的截屏功能(需要先把搜狗输入法的截屏快捷键设置为ctrl+alt+s)
PrintScreen::^!s

;;;有时候，一手握着鼠标，另一只手ctrl+c，ctrl+v，这时候想按下换行手还要移动很远，去按enter键很麻烦.索性把CapsLock键换成enter键。
;;;和右侧alt转成End键,在写代码的时候更常用.
;$CapsLock::End
$Ralt::End

;;;把CapsLock 设置为 反向tab键（即 Shift+Tab）
$CapsLock::
    send,+{tab}
return


;;关闭当前应用程序,改为alt+esc(暂时不使用这个功能)
;;!esc::!f4

;;关闭当前窗口(如果一个app有多个打开的窗口的话,就是关闭当前使用中的一个)
!w::^w


;;修复z键，(因为键盘键位z坏了--点击一次z经常出现多个z，现在进行修复)
;$z::PressKeyManyTimes("filter_z","filter_z","filter_z",120)
filter_z(){
	send,{z}
}

;;左边Alt是将中文标点符号转换为英文标点符号;右Alt是将英文标点符号替换为中文标点符号
;;Alt双击是替换刚才输入的最后一个标点符号;Alt三连击是替换光标所在整个行内的标点符号
~Lalt::PressKeyManyTimes("lalt_event_kp1","lalt_event_kp2","lalt_event_kp3")
;;;~Ralt::PressKeyManyTimes("ralt_event_kp1","ralt_event_kp2","ralt_event_kp3")

;GetMarker_CN_EN := "。，；？"

lalt_event_kp1()
{
	send,{lalt}
}

lalt_event_kp2(){	
	send,+{left}
	output := MyUseClipReplace(["。","."],["，",","],["；",";"],["（","("],["）",")"])
	send,{text}%output%
}

lalt_event_kp3(){
	send,{end}
	send,+{home} 
	output := MyUseClipReplace(["。","."],["，",","],["；",";"],["（","("],["）",")"])
	send,{text}%output%
}

ralt_event_kp1()
{
	send,{ralt}
}

ralt_event_kp2(){	
	send,+{left}
	output := MyUseClipReplace([".","。"],[",","，"],[";","；"],["(","（"],[")","）"])
	send,{text}%output%
}

ralt_event_kp3(){
	send,{end}
	send,+{home} 
	output := MyUseClipReplace([".","。"],[",","，"],[";","；"],["(","（"],[")","）"])
	send,{text}%output%
}


;;这个功能暂时通过powertoy实现。否则停止下列代码的注释
;;由于Ctrl+s 操作起来不方便，将Alt+s映射到Ctrl+s
;$!s:: ;保存
;	Send, ^s
;	sleep,400
;	send, {esc}
;return

;;格式刷(奇数次复制格式，偶数次的时候粘贴格式。无论是复制格式还是粘贴格式，都需要先选中目标文本)
$#f::
	global wfPressCount += 1 

	if(mod(wfPressCount,2)=0){
		;msgbox,偶数
		Send,^+v
	}else{
		;msgbox,奇数
		Send,^+c
	}
return



;;;以下方向键重定义，使用space方案代替alt方案。暂时注释。
;;;以下内容为方向键重定义
;$!i::Send {Up} 
;$!k::Send {Down}
;$!j::Send {Left}
;$!l::Send {Right}
;$!h::Send {Home}
;$!;::Send {End}

;;;重置Space按键  ***  space
space::Send {space}

^space::Send ^{space}
#space::Send #{space}
^#space::Send ^#{space}
!space::Send !{space}
^!space::Send ^!{space}

;  *** space + Num
space & 1::Send {space}
space & 2::Send {space}{space}
space & 3::Send {space}{space}{space}
space & 4::Send {space}{space}{space}{space}
space & 5::Send {space}{space}{space}{space}{space}
space & 6::Send {space}{space}{space}{space}{space}{space}
space & 7::Send {space}{space}{space}{space}{space}{space}{space}
space & 8::Send {space}{space}{space}{space}{space}{space}{space}{space}
space & 9::Send {space}{space}{space}{space}{space}{space}{space}{space}{space}


;  *** space + [] (windows virual desktop switcher)
space & [::Send ^#{left}
space & ]::Send ^#{right}

;  *** space + XX
#if GetKeyState("space", "P")
f & i:: Send +{up}
f & j:: Send +{left}     
f & k:: Send +{down}
f & l:: Send +{right}
d & i:: Send ^{up}
d & j:: Send ^{left}
d & k:: Send ^{down}
d & l:: Send ^{right}
;g & i:: Send ^+{up} 
g & j:: Send ^+{left}
;g & k:: Send ^+{down}
g & l:: Send ^+{right}

i:: Send {up}
j:: Send {left}
k:: Send {down}
l:: Send {right}
h:: Send {home}
n:: Send {end}
,:: Send {Pgup}
.:: Send {Pgdn}

b::Send,{backspace}
d::Send,{del}

c:: Send ^c
x:: Send ^x
v:: Send ^v
z:: Send ^z

return
;;;重置Space按键结束  ***  space




;输入法搜狗，切换方式
;右Shift 在各种输入法之间切换
~RShift::Send, #{Space}
;========================
;左Shift 在sogou输入法内，进行中英文的切换（在搜狗输入法内设置）
~LShift::
    switch_sg_ime(1)
    send,+	    
return


;;Ctrl + Shift + C锁定搜狗中文输入法
;;Ctrl + Shift + E锁定英文输入法
^+c::
	switch_sg_ime(1)
return 


^+e::
	switch_sg_ime(0)
return
 
switch_sg_ime(ime := "A")
{
	SetCapsLockState , AlwaysOff
	if (ime = 1)
	{
		DllCall("SendMessage", UInt, WinActive("A"), UInt, 80, UInt, 1, UInt, DllCall("LoadKeyboardLayout", Str,"00000804", UInt, 1))
		
	}
	else if (ime = 0)
	{
		DllCall("SendMessage", UInt, WinActive("A"), UInt, 80, UInt, 1, UInt, DllCall("LoadKeyboardLayout", Str,, UInt, 1))
	}
	else if (ime = "A")
	{
		Send, #{Space}
	}
}
Return




;启动windows 的邮件功能
PrintScreen & m::
#m::
#!^m::send ^!m

; PrintScreen & s::
; #!^s::run "D:\tools\office\Snipaste-2.5.6-Beta-x64\Snipaste.exe"
PrintScreen & e::
#!^e::run "C:\Program Files\Everything\Everything.exe"

PrintScreen & n::
#!^n::run C:\Program Files\Microsoft Office\root\Office16\ONENOTE.EXE
PrintScreen & t::
#^!t::run taskmgr.exe
;;;面板（面霸8）
PrintScreen & 8::
#^8::
#^!8::run control.exe
;;;命令（命0）
PrintScreen & c::
#!^0::run cmd.exe
PrintScreen & i::
#!^i::run C:\windows\system32\inetsrv\iis.msc
#^b::
_result:=UserDisplay()
MsgBox, You entered %_result%
return

UserDisplay(){
	InputBox, UserInput, Phone Number, Please enter a phone number., , 640, 480

	if (ErrorLevel)
		MsgBox, CANCEL was pressed.
	else
		;MsgBox, You entered "%UserInput%"!
		return %UserInput%
}


;;;;;;;;;;;;;删除一整行
$!d::   ;alt+d
	Send, {Home}   ;输出回车
	Send, +{End}   ;输入shitf键+end键
	Send, {delete}   ;输入delete键
return 
;;;;;;;;;;;;;复制一整行
$!c::
	Send, {home}
	Send, +{end}
	Send, ^c   ;输出ctrl+c,复制一整行
return
;;;;;;;;;;;;;另起一行粘贴内容 
$!v:: 
	Send, {end}
	Send, {enter}
	Send, {text}%clipboard%    ;将剪贴板的内容输出 
return  
;;;;;;;;;;;;;分隔符 (暂时使用热文本替换的方式,热文本为 ---- (4个-符号))
;~!-:: ;请在中文输入法下,8个长度差不多占比手机屏幕全长
;	Send, +-+-+-+-+-+-+-+-
;return


$F10:: ;;在 msedge 中设置快捷键 ctrl+0 (调用沙拉词典)
    Send,^0
return



;;用Alt+↑ 、Alt+↓ 映射查找结果集的上一条、下一条
;;jetBrains系列软件在Ctrl+F搜索模式下，不用重新映射，直接使用↑，↓就可以了。
;;1、在edge浏览器中
#IfWinActive ahk_exe msedge.exe
{
	;【1】将 Alt+↑ 映射查找结果集的上一条
	!Up::send,^+g

	;【2】将 Alt+↓ 映射查找结果集的下一条h
	!down::send,^g

	;;;将F6设置为新建tab
	F6::Send,^t
	;;;将F4设置为关闭tab
	;F4::Send,^w

    ;;将F8设置为简阅的快捷键(需要提前设置简阅的快捷键为ctrl+r)
    F8::
        send, F4
        send, ^c
        send, {read://}
        send, ^v
        return

	;;;双击左键关闭当前tab
	;LButton::
	;If (A_PriorHotkey=A_ThisHotkey) and (A_TimeSincePriorHotkey<300)
	;{
	;	;send, ^w
	;	MouseClick,Middle
	;}
	return
}
#IfWinActive

;;2、在Editplus中
#IfWinActive ahk_exe editplus.exe
{
	;【1】将 Alt+↑ 映射查找结果集的上一条
	!Up::send,!p

	;【2】将 Alt+↓ 映射查找结果集的下一条h
	!down::send,!f

    ;;;以下代码验证~符号的功能：~是保留原来按键功能的基础上加入新定义的功能
    ;;; - 如果不加~符号，那么按下a的时候会输出 BBB
    ;;; - 如果加上~符号，那么按下a的时候会输出 aBBB
    ; ~a::Send BBB
}
#IfWinActive

;;3、在资源管理器中
#IfWinActive ahk_exe Explorer.EXE
{

}
#IfWinActive


;;4、在腾讯的桌面管理器中
#IfWinActive ahk_exe DesktopMgr64.exe
{
    ~esc:: 
	PressKeyManyTimes("","press_2_esc_event4DesktopMgr","",300)		
	return

	press_2_esc_event4DesktopMgr()
	{
		click right
        ;;根据右键菜单的情况设置down,up的数量，使其定位到"一键桌面整理"
        Send, v
        Send, v
        Send, {down}{down}{down}{down}{down}{enter}
	}
}
#IfWinActive

;;;5. 如果是在onenote中，就映射F系列快捷键
#IfWinActive ahk_exe ONENOTE.EXE
{
	F4:: ;标题重映射1
		;;;
        ;;; 先清除掉其他格式
        Send,^+n

        ; ;;; 启用MarkDown格式
        ; send,^,
        ; sleep,300

        send,{home}
        send,{text}#
        send,{space}
        send,{text}※
        Send,^!1
        send,{end}
		;;;Send,!hul{end}{up}{up}{up}{up}{left}{left}{left}{enter}

        ;;;退出 MarkDown 模式
        send,^,

        ;;; 顶格表示
        send,{home}
        send,+{tab}
        send,+{tab}
        send,+{tab}
		return

	F3:: ;标题重映射2		
		;;使用下划线
		Send,{home}
        send,{text}##
        send,{space}
		Send,{text}__§
        send,{end}
        send,{text}__
		;Send,{space}
		;Send,{home}{right}{right}{right}+{end}
		
		Send,^!2
		;Send,^u
		;Send,^b
		;;不使用前缀箭头
		;Send,!hul{end}{up}{up}{left}{left}{left}{left}{enter}

        send,^,

        ;;; 顶格表示
        send,{home}
        send,+{tab}
        send,+{tab}
        send,+{tab}
		return

    F2:: ;有序列表显示
        Send,^/
        return

    F1:: ;无序列表显示(用一个短横线开头)
    	Send,^+n
		Send,!hul{right}{right}{right}{enter}
        ;Send,!hul{end}{up}{left}{left}{left}{enter}
		return

    $F5:: ;单击时候切换MD；双击的时候清除所有的格式,并保持行首没有缩进
		PressKeyManyTimes("press_f5_1_onenote","press_f5_2_onenote","press_f5_2_onenote",500)	
    return	

    press_f5_1_onenote()
    {
        switchMD(0)
    }
    
    press_f5_2_onenote(){
        Send,^+n
        Send,+{tab}
        Send,+{tab}
    }
    return
 
	
    F6:: ;;突出显示（加粗，加下划线)
        Send,^b
        Send,^u
        return    	
    	
    F7:: ;背景突出
        PressKeyManyTimes("press_f7_1_onenote","press_f7_2_onenote","press_f7_2_onenote",500)	
        return

        press_f7_1_onenote()
        {
            ; clipboard = ; 清空剪贴板
            ; send,^c
            ; ClipWait,1
            ;msgbox,%clipboard%
            ;determineIsContentSelected()


            ; isExistContent := determineIsContentSelected()
            ; msgbox,%isExistContent%
            ; if(isExistContent==true){
            ;     msgbox,有
            ; }else{
            ;     msgbox,无
            ; }


            
            clipboard = ; 清空剪贴板
            switchMD()
            send,^c
            send,^x
            sleep,400
            send,{text}``
            send,^v
            send,{text}``
            switchMD()




            ; ;;;;TODO 这个地方判断需要完成 
            ; ;;; TODO 用 wrapContent 完成此功能
            ; clipboard = ; 清空剪贴板
            ; send,^c
            ; ClipWait,1
            ; msgbox,%clipboard%
        }

        press_f7_2_onenote()
        {
            Send,!hfc{down}{enter}
            Send,!hi{down}{right}{right}{right}{right}{enter}
        }

        ;;; 判断是否有内容被选中
        determineIsContentSelected(){
            clipboard_old := clipboard

            compareString := "iamxiedali20220225"
            clipboard := compareString            

            send,^c
            ;ClipWait,1
            sleep,350

            ;msgbox,%clipboard%
            if(clipboard == compareString){
                ;msgbox,false
                return false
            }else{
                ;msgbox,true
                return true
            }
        }
        return
    
    f8:: ;行首突出(红色行首)
    space & r:: 
        myfunc_em()
        ;Send, !hi
        Send, {home}{down}{down}{down}{down}{down}{down}{right}{right}{right}{right}{right}{enter}
       
        switchMD()
    return

    F9:: ;用表格格式化信息
		Send,!nt{enter}	
		;Send,^i
		click right
		Send,ah{down}{right}{down}{enter}
		return

	space & f9:: ;用表格格式化信息
		Send,!nt{enter}	
		
		click right
		Send,ah{up}{up}{up}{up}{up}{up}{up}{up}{up}{up}{up}{enter}
		click right
		Send,ah{down}{right}{home}{down}{right}{right}{right}{right}{right}{right}{enter}
		return
    
    F10::
    ; RShift::
    ; $CapsLock::    
        switchMD()
    return

    ;;;
    ;;; F10:: send,{F5}

    f11:: ;补充说明性质的文字
        myfunc_em()
        ; ;Send, !hfc
        Send, {home}{down}{down}{right}{enter}
        Send, {home}+{end}
        Send, !hfs9{enter} 
        send, {esc}
        send, {end}

        switchMD()
    return

    F12:: ;代码格式化(需要安装代码高亮插件NoteHighLight)
		Send,!yc
		return

    ;;;绿色行首
    space & g::
        myfunc_em()
        Send, {home}{down}{down}{down}{down}{down}{down}{right}{right}{right}{right}{right}s{right}{right}{right}{right}{enter}
    return

    ;;;紫色行首
    space & t::
        myfunc_em()
        Send, {home}{down}{right}{right}{right}{right}s{right}{right}{right}{right}{enter}
    return

    ;;;最近的一次颜色
    space & f::
        myfunc_em()
        ;Send,{esc}
        Send, ^!h
    return

    myfunc_em(){
        Send,{home}
        Send, ▌
        Send, {home}
        Send, +{right}
        Send, !hfc
        ;;Send, ^!h
    }
    return

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;; 在 MarkDown 格式和普通的 OneNote 格式间切换
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    switchMD(seconds=300){
        if(seconds>0){
            sleep,seconds
        }
        
        Send,^,
    }
    return
	

	~esc:: ;调用历史面板
		PressKeyManyTimes("press_1_esc_event","press_2_esc_event","press_2_esc_event",300)		
		return

		press_1_esc_event()
		{
			send,{esc}
		}

		press_2_esc_event()
		{
			Send,!sea
		}
    return
	
	$^b:: ;以普通文本格式粘贴信息
		;;1、调用窗口菜单方式
		Send,!hvt
		sleep,200
		send,{esc} ;;去掉悬浮的ctrl选项卡
		;;2、调用右键菜单方式(不能很好判断I形状的文本输入点，默认是在鼠标箭头光标地方插入。暂时不使用本方法。)
		;click right
		;Send, {down}{down}{down}{right}{right}{enter}
    return



	; $!f::
	; 	clipboard=
	; 	sleep,200
	; 	send,^c
	; 	clipwait,2
	; 	Loop
	; 	{
	; 		StringReplace, clipboard,clipboard, `r`n,`n, UseErrorLevel
	; 		if ErrorLevel = 0 ;全部替换完，退出循环
	; 		break
	; 	}
	; 	Loop
	; 	{
	; 		StringReplace, clipboard,clipboard, `n`n`n,`n-----------------------------`n, UseErrorLevel
	; 		if ErrorLevel = 0 ;全部替换完，退出循环
	; 		break
	; 	}
	; 	Loop
	; 	{
	; 		StringReplace, clipboard,clipboard, %A_SPACE%,, UseErrorLevel;替换空格
	; 		if ErrorLevel = 0
	; 		break
	; 	}
	; 	Send,{text}%clipboard%

	; 	sleep,400
	; 	send,{esc}
	; 	return
}   
#IfWinActive

;;;6. 在MyLifeOrganized中配置快捷键(大部分功能在MLO内部配置，此处仅配置其软件本身无法完成的)
#IfWinActive ahk_exe mlo.exe
{
    ;;显示当前AHK的版本号
    ~LButton & f1::
        Msgbox, F9删除; `nF4移动条目; `nF4双击快速移动条目(移动到上次的目标位置)
    return


    ;;;暂时不使用本段脚本，因为mlo支持 alt+enter 保存并关闭 快速信息弹窗
	; ;;;用alt+回车调用 保存信息&关闭快捷任务输入窗口
	; !enter:: 
    ;     send,^{enter}
    ;     ;;保存任务后，自动关闭窗口(现在在mlo内设置)
    ;     ;send,!o
    ;     ;;;;非常奇怪，执行完毕后会alt选中背景app的菜单，通过此操作清除菜单选定
    ;     ;;;;send,{esc}
    ; return

    ;;;截获删除功能，将要删除的条目移动到"待删除(Deleted)"文件夹,这个文件夹的名称内必须有"Deleted"
    ;;;如果要真正删除，就使用mlo里面的删除图标(删除图标的删除功能没有截获).
    F9::
        send,^m ;;打开移动对话框
        Send,!f
        send,{text}Deleted
        ;;;因为文件io需要一段时间响应，因此这里加入延时。
        msgbox,1,,2秒钟之后自动移入待删除文件夹,2
        ;sleep,1000
        send,{down}{down}{enter}
    return

    ~F4:: ;快速移动条目到目标文件夹
        PressKeyManyTimes("press_1_f4_event","press_2_f4_event","press_2_f4_event",300)		
		return

		press_1_f4_event()
		{
			send,^m
		}

		press_2_f4_event()
		{
			Send,^m{enter}{enter}
		}
    return
}
#IfWinActive


;;;7. 在 EditPlus 中
#IfWinActive ahk_exe editplus.exe
{
    ;;修改ahk脚本之后，按F5重新载入脚本
    ;;(现在一般都是在editplus、VSCode里面修改，所以加入对环境的判断)
    $F5::
        reload
    return
}
#IfWinActive

;;;8. 在 VSCode 中
#IfWinActive ahk_exe Code.exe
{
    ;;;修改ahk脚本之后，按F5重新载入脚本
    $F5::
        reload
    return

    ;;;启动命令面板^+p 或者 ^+a
    f4::Send,^+a
}
#IfWinActive


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;热字符串



;在开发环境phpstorm中的映射
#IfWinActive ahk_exe phpstorm64.exe
{
	/* 
	将这段 全局中是sss替换${}
	PHP中是 sss替代 $
	*/
	;【1】将 sss替换为 $ 符号
	:*:sss::
	    SendInput {text}$
	return
	

	;【2】将 ... 替换为 -> 符号
	;:*:...:: ;;新版本phpstorm对.符号进行了特别处理,本热字符串转换失效,请使用,,
	;;SendInput {-}{>}
	;Send,->
	;return	

	; ;【3】注释符号的替换
	; :*:///:: ;;将///注释转换成/**注释
	; SendInput {text}/**
	; Send,{enter}
	; return	

	;;;将win+f替换为文件全局格式化
	#f::send,!+^l
}
#IfWinActive

;在开发环境webstorm中的映射
#IfWinActive ahk_exe webstorm64.exe
{
	; ;【1】注释符号的替换
	; :*:///:: ;;将///注释转换成/**注释
	; SendInput {text}/**
	; Send,{enter}
	; return	

}
#IfWinActive

;在开发环境pycharm中的映射
#IfWinActive ahk_exe pycharm64.exe
{
	;【1】注释符号的替换
	:*:///:: ;;将///注释转换成/**注释
	SendInput {text}"""
	;;;因为pycharm默认为双引号补全另外一半，因此删除去另外3各双引号
	Send,{del}{del}{del}
	Send,{enter}
	return	

	;;;将win+f替换为文件全局格式化
	#f::send,!+^l

}
#IfWinActive

;在开发环境微信开发者工具中的映射
;;AHK在微信开发工具中无法使用?
#IfWinActive ahk_exe wechatdevtools.exe
{

}
#IfWinActive

#IfWinActive ahk_exe Obsidian.exe
{
    ;;; 使用 Git 作为同步工具的话，需要先安装 git 插件，然后在配置 Obsidian 内配置 快捷键，最后在 AHK 内映射（因为 Obsidian 不支持仅用 Fx功能键，他需要 Fx跟 Alt、Ctrl等配合）
    ;;; 目前不使用 Git 作为同步工具，暂时屏蔽此快捷键（现在使用的 OneDrive 同步内容）
    ; F11:: send,!{F11}
    ; F12::
    ;     PressKeyManyTimes("press_1_f12_Obsidian","press_2_f12_Obsidian","press_2_f12_Obsidian",300)		
	; 	return

	; 	press_1_f12_Obsidian()
	; 	{
	; 		send,!{F10}
	; 	}

	; 	press_2_f12_Obsidian()
	; 	{
	; 		send,!{F12}
	; 	}
    ; return


    F4:: ;;; 定义用 # 开头的标题
        
        isEmptyLine := determineEmptyLine()

        if(isEmptyLine){
            send,{text}#
            send,{space}
        }else{
            send,^c
            firstChar := SubStr(clipboard, 1 ,1)

            send,{home}
            send,{text}#

            if(firstChar!="#"){   
                send,{space}
            }    
            send,{end}            
        }		
    return

    F8:: ;;; 复选框
        send,{text}- [ ]
        send,{space}
        return

    F9:: ;;; 插入图片的模板
        Send,{text} ![图片]()
        Send,{left}
        return


    F12:: ;;; 插入代码块
        send,{text}``````shell
        send,`n`n
        send,{text}
        send,{up}
    return
}
#IfWinActive


;VK05::MsgBox,hi china

;;;;鼠标手势研究
/*
rbutton::     
  mousegetpos xpos1,ypos1
  settimer,gtrack,1               
  return
  rbutton up::
  settimer,gtrack,off           
  msgbox,,,%gtrack%,1
  gtrack=
  return
  gtrack:
  mousegetpos xpos2,ypos2
  track:=(abs(ypos1-ypos2)>=abs(xpos1-xpos2)) ? (ypos1>ypos2 ? "u" : "d") : (xpos1>xpos2 ? "l" : "r")
  if (track<>SubStr(gtrack, 0, 1)) and (abs(ypos1-ypos2)>4 or abs(xpos1-xpos2)>4)
     gtrack.=track
  xpos1:=xpos2,ypos1:=ypos2
  return
*/

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 各软件专用的热键、热字母在前面；通用的热键、热字母在后面。
;;; 这样能保证从上到下的生效优先级。
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#IfWinActive ahk_group DevGroup_jet
{
    ;;;方法级的运行(在待运行的方法上右键，选择"运行...(Ctrl+Shift+F10)")，在ide内找不到重新分配快捷键。暂时在ahk内映射。
    f5::^+f10

    ;;; F6单击：代码全部收缩到 1级；F6双击：代码全部展开到 2级
    f6::PressKeyManyTimes("press_1_f6_event","press_2_f6_event",300)

    press_1_f6_event(){
        send,^+{NumpadMult}{1}
    }

    press_2_f6_event(){
        send,^+{-}
    }
}
#IfWinActive

#IfWinActive,ahk_group DevGroup_all
{
    ~LButton & t:: ;;是否在某开发工具内有效，进行测试。（按下鼠标左键和键盘t键）
    {
        MsgBox,hello developer, this is a test 。
    }

    ;【3】注释符号的替换
    :*:///:: ;;将///注释转换成/**注释
        SendInput {text}/**
        sleep,200
        Send,{enter}
    return

    ; ;;;; 先判断当前输入法的中英文状态，然后决定是输入中文还是英文的括号
    ; :*:ccc::
    ; :*:(::
    ;     send, {text}()
    ;     send, {left}
    ; return

    ; :*:yyy::
    ; :*:"::
    ;     send, ""
    ;     send, {left}
    ; return
}
#IfWinActive
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 1.1.  全局热字母 (更多全局热键，在文档末尾)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;快速输入日期的热字符串
;;2021-06-17
:*:\\dd::
	FormatTime, now_date, %A_Now%, yyyy-MM-dd ;格式化当前时间
	Send, {text}%now_date% ;发送
Return

;;快速输入日期时间的热字符串
;;2021-06-17 10:17:00
:*:\\dt::
	FormatTime, now_date, %A_Now%, yyyy-MM-dd HH:mm:ss ;格式化当前时间
	Send, {text}%now_date% ;发送
Return

;;快速输入 段落分隔符
:*:---:: ;8个长度差不多占比手机屏幕全长
	;;Send,────────────────────────

    ;;; 使用 OneMark 后，英文字体统一被改成了 Calibra，
    ;;; 占用宽度是原来 微软雅黑的一半了，因此要加长一些
    Send,{text}─────────────────────────────────────
Return

:*:===:: ;8个长度差不多占比手机屏幕全长
	Send,══════════════════════════
Return

; :*:,,,:: ;8个长度差不多占比手机屏幕全长
; 	Send,┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
; Return

:*:\\\\::{text}\\

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 在所有软件之后生效的全局热字母
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

:*:ccc::
:*:(::
    ime := getIME()
    if(ime==1){
        send,{text}（）
    }else{
        send,{text}()
    }
    
    send, {left}
return

:*:yyy::
:*:"::
    ime := getIME()
    if(ime==1){
        send,{text}“”
    }else{
        send,{text}""
    }
    
    send, {left}
return

:*:eee::
:*:kkz::
:*:[::
    send, {text}[]
    send, {left}
return

:*:bbb::
    send, {text}{}
    send, {left}
return

:*:iii::
    send, {text}!
return

:*:aaa::
    send, {text}@
return

:*:nnn::
    send, {text}&
return

;将 sss替换为 ${} 符号
:*:sss::
	SendInput, {text} ${}
	send, {left}
return

:*:fff::
:*:``::
    send, {text}````
    send, {left}
return

:*:ddd::
    send, {text}=
return

:*:jjj::
    send, {text}#
return

:*:uuu::
    send, {text}_
return

:*:...::
:*:.yy::
:*:.nn::
    send, {text}.
return

:*:.hh::
    send, {text}。
return

:*:,,,::
:*:,yy::
:*:,nn::
    send, {text},
return

:*:,hh::
    send, {text}，
return


:*:a//::
    send, {text}A
return

:*:b//::
    send, {text}B
return

:*:c//::
    send, {text}C
return

:*:d//::
    send, {text}D
return

:*:e//::
    send, {text}E
return

:*:f//::
    send, {text}F
return

:*:g//::
    send, {text}G
return

:*:h//::
    send, {text}H
return

:*:i//::
    send, {text}I
return

:*:j//::
    send, {text}J
return

:*:k//::
    send, {text}K
return

:*:l//::
    send, {text}L
return

:*:m//::
    send, {text}M
return

:*:n//::
    send, {text}N
return

:*:o//::
    send, {text}O
return

:*:p//::
    send, {text}P
return

:*:q//::
    send, {text}Q
return

:*:r//::
    send, {text}R
return

:*:s//::
    send, {text}S
return

:*:t//::
    send, {text}T
return

:*:u//::
    send, {text}U
return

:*:v//::
    send, {text}V
return

:*:w//::
    send, {text}W
return

:*:x//::
    send, {text}X
return

:*:y//::
    send, {text}Y
return

:*:z//::
    send, {text}Z
return

; :*:`:`:`:::
; :*:`:yy::
; :*:`:nn::
;     send, {text}:
; return

; :*:`:hh::
;     send, {text}：
; return


;;;快速插入 MarkDown 的超链接
:*:mmh::
    send, {text}[信息来源]()
    send, {left}
return

;;;快速插入 MarkDown 的图片
:*:mmi::
    send, {text}![图片]()
    send, {left}
return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 1.1. 全局热字母 结束
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;自定义函数部分
PressTwice(pressEvent,timer=300){
    If (A_PriorHotkey=A_ThisHotkey) and (A_TimeSincePriorHotkey<timer)
    {
        if (IsFunc(pressEvent))
        {
            %pressEvent%()
        }
    }
}
     	


;AHK多次按下某个键通用的处理函数。以下是通用的被调用部分。
;其中press1Event,press2Event,press3Event是处理点击、双击、三击的子函数
;（使用的时候，用双引号直接传递这三个函数的名称）
PressKeyManyTimes(press1Event,press2Event="",press3Event="",timer=500){
	global gnPressCount += 1 

    If gnPressCount = 1 
	{
		global _g_pc1=press1Event
		global _g_pc2=press2Event
		global _g_pc3=press3Event
        SetTimer, ProcSubroutine, %timer%		
	}
	return


	ProcSubroutine:
	{
		global _g_pc1
		global _g_pc2
		global _g_pc3

		global gnPressCount
	 
		; 在计时器事件触发时，需要将其关掉	 
		SetTimer, ProcSubroutine, Off
	 
		If gnPressCount = 1 
		{ 
			; 第一类行为 
			if (IsFunc(_g_pc1))
			{
			    %_g_pc1%()
			}			
		}

		If gnPressCount = 2 
		{ 
			;; 第二类行为 
			if (IsFunc(_g_pc2))
			{
			    %_g_pc2%()
			}
		}

		If gnPressCount = 3 
		{ 
			if (IsFunc(_g_pc3))
			{
			    %_g_pc3%()
			}
		}
	 
		; 在结束后，还需要将按键次数置为0，以方便下次使用	 
		gnPressCount := 0 
		Return	 
	}
    return
}


;;在不影响短按的情形下，对长按某个按键的处理
;;key表示某个具体的按键名称，（注意用引号包裹起来）
;;longPressEvent 长按此按键的处理程序，是另外定义的一个函数(此处使用的是需要用引号包裹起来的函数名称)
MyPressKeyLong(key,longPressEvent){
	KeyWait, %key%
	If (A_TimeSinceThisHotkey > 400)		
	{	
		if (IsFunc(longPressEvent))
		{
		    %longPressEvent%()
		}
	}
	Else
		;SendInput, % GetKeyState("CapsLock", "T") ? "T" : "t"
		Send, %key%
	Return	
}


;;获取给定数据的数据类型
;;TODO目前可以判定的数据类型有限，更多数据类型根据需要添加
MyGetType(v) {
    if IsObject(v)
    {
	return "array"
    }
    return v="" || [v].GetCapacity(1) ? "string" : InStr(v,".") ? "float" : "int"
}


wrapContent(prefixer,postfixer){
		clipboard=
		sleep,200
		send,^c
		clipwait,2
		
		;;需要判断剪切板内的数据是否以回车换行结尾。
		_len := StrLen(clipboard)
		_last := SubStr(clipboard, -1)
		if  _last = `r`n
		{
			;Msgbox,回车换行
			_newLen:= _len-2
			clipboard:= SubStr(clipboard, 1,_newLen)			
		}
		
		send,{text}%prefixer%
		send,{text}%clipboard%
		send,{text}%postfixer%
		return
}



;;通过将选定的字符串保存进入剪贴板，
;;然后在剪贴板内，对其进行替换
;;最后再输出回来
;; params* 是一个可变长度的参数，每个参数元素都是一个数组，具体格式[oldValue,newValue]
;;这样数组元素可以有多个。
;;也就是说如果只是替换一组的话,直接传递两个参数oldValue,newValue就可以了
;;如果要替换多个子字符串,那么每一个oldValue,newValue构成一个数组[oldValue,newValue],传递多组就可以了
;; （替换多组的时候，可以忽略前面两个参数。）
MyUseClipReplace(oldValue="",newValue="",params*){
	
	if(MyGetType(oldValue)= "string" and MyGetType(newValue)= "string"){
		params.push([oldValue,newValue])
	}

	if(MyGetType(oldValue)= "array"){
		params.push(oldValue)
	}

	if(MyGetType(newValue)= "array"){
		params.push(newValue)
	}
	

	maxIndex :=params.MaxIndex() 
	;MsgBox,%maxIndex%
	
	
	clipboard_old := clipboard
	clipboard= 
	sleep,200
	send,^c
	clipwait,2
	
	for index,param in params
	{			
		oValue:= params[index][1]
		nValue:= params[index][2]
		;MsgBox,%oldValue%,%newValue%
		Loop
		{
			StringReplace, clipboard,clipboard, %oValue%,%nValue%, UseErrorLevel
			if ErrorLevel = 0 ;全部替换完，退出循环
			break
		}			
	}
	

	output:= clipboard
	clipboard := clipboard_old
	return %output%	
}

;;; 判断当前是否为空行
determineEmptyLine(){
    compareString := "iamxiedali20220225"
    clipboard := compareString            

    send,^c

    if(clipboard == compareString){
        return true
    }else{
        return false
    }
}


;-----------------------------------------------------------
; “获得 Input Method Editors 的状态”(目前对搜狗输入法有效，其他未验证)
;   -- 如果返回1，表示搜狗输入法中文状态
;   -- 如果返回0，表示搜狗输入法英文状态
;-----------------------------------------------------------
getIME(WinTitle="")
{
    ifEqual WinTitle,,  SetEnv,WinTitle,A
    WinGet,hWnd,ID,%WinTitle%
    DefaultIMEWnd := DllCall("imm32\ImmGetDefaultIMEWnd", Uint,hWnd, Uint)
 
    DetectSave := A_DetectHiddenWindows
    DetectHiddenWindows,ON
    SendMessage 0x283, 0x005,0,,ahk_id %DefaultIMEWnd%
    DetectHiddenWindows,%DetectSave%
    Return ErrorLevel
}


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;
;;;;;功能验证与demo


;$t::MyPressKeyLong("t","longPressEvent")
longPressEvent(){
	MsgBox,Hi Mr.Xie
}



/*
LButton & t::
	;arr:=[1,1,2]
	arr:=12345
	;tt:= MyGetType(arr)

	if IsObject(arr)
	    {
		tt:=  "array"
	    }

	p:= [arr,"www"]
	ff:= IsObject(p)
        Msgbox,% "变量" p "是Object类型吗?" ff
	
	eall:= p.GetCapacity()
	Msgbox,% "变量" p "占用的内存空间为" eall
	e1:= p.GetCapacity(1)
	Msgbox,% "变量" p "第一个item占用的内存空间为" e1
	maxIndex := p.MaxIndex()
	MsgBox,% "变量" p "内共有元素个数为" maxIndex

	tt:= "" || [arr].GetCapacity(1) ? "string" : InStr(arr,".") ? "float" : "int"

	;Msgbox,%tt%
return
*/

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;第二段自定义部分结束
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;以下为研究学习
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; LButton & s::
; 	myData:= 123
; 	if (myData is number)	
; 	{
; 		MsgBox,%myData% is number.
; 	}

; 	if (myData is integer)
; 	{
; 		MsgBox,%myData% is integer.
; 	}

; 	if (myData is alpha)
; 	{
; 		MsgBox,%myData% is string.
; 	}

; 	if (myData is space)
; 	{
; 		MsgBox,%myData% is space.
; 	}

; 	if (myData is time)
; 	{
; 		MsgBox,%myData% is datetime.
; 	}
; return