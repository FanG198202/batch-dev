# backup_userfiles_robocopy.bat 流程圖

```mermaid
flowchart TD
    Start([開始])
    AdminCheck{以系統管理員執行？}
    TryElevate{提升權限成功？}
    ArgsHelp{"第一參數為 -?"}
    ArgsGiven{"有給參數？"}
    DstGiven{"有給目標路徑？"}
    UserGiven{"有給用戶名稱？"}
    InteractiveInput[互動模式輸入來源、用戶、目標]
    Main[進入 MAIN 流程]
    Confirm{"使用者確認繼續？(Y/N)"}
    SrcExist{"來源資料夾存在？"}
    DstExist{"目標上層資料夾存在？"}
    MkdirOk{"建立目標資料夾成功？"}
    SrcSizeOk{"取得來源資料夾大小成功？"}
    DstFreeOk{"取得目標磁碟剩餘空間成功？"}
    SpaceEnough{"目標空間>=來源大小？"}
    RobocopyError{"robocopy errorlevel>=8？"}
    ShowUsage[顯示說明並結束]
    Cancel[已取消作業]
    Exit[結束]
    ErrorAdmin[顯示「請用系統管理員」錯誤並退出]
    ErrorSrc[顯示來源不存在並退出]
    ErrorMkdir[顯示建立失敗並退出]
    ErrorSrcSize[顯示無法取得來源大小並退出]
    ErrorDstFree[顯示無法取得目標空間並退出]
    ErrorNotEnough[顯示空間不足並退出]
    RobocopyOk[備份完成]
    RobocopyFail[robocopy 發生錯誤，檢查 log]
    Pause[暫停]

    Start --> AdminCheck
    AdminCheck -- 是 --> ArgsHelp
    AdminCheck -- 否 --> TryElevate
    TryElevate -- 是 --> Exit
    TryElevate -- 否 --> ErrorAdmin
    ErrorAdmin --> Pause --> Exit

    ArgsHelp -- 是 --> ShowUsage
    ArgsHelp -- 否 --> ArgsGiven
    ArgsGiven -- 否 --> InteractiveInput --> Main
    ArgsGiven -- 是 --> DstGiven
    DstGiven -- 否 --> ShowUsage
    DstGiven -- 是 --> UserGiven
    UserGiven -- 否 --> ShowUsage
    UserGiven -- 是 --> Main

    ShowUsage --> Pause --> Exit

    Main --> Confirm
    Confirm -- 否 --> Cancel --> Pause --> Exit
    Confirm -- 是 --> SrcExist
    SrcExist -- 否 --> ErrorSrc --> Pause --> Exit
    SrcExist -- 是 --> DstExist
    DstExist -- 是 --> SrcSizeOk
    DstExist -- 否 --> MkdirOk
    MkdirOk -- 否 --> ErrorMkdir --> Pause --> Exit
    MkdirOk -- 是 --> SrcSizeOk

    SrcSizeOk -- 否 --> ErrorSrcSize --> Pause --> Exit
    SrcSizeOk -- 是 --> DstFreeOk
    DstFreeOk -- 否 --> ErrorDstFree --> Pause --> Exit
    DstFreeOk -- 是 --> SpaceEnough
    SpaceEnough -- 否 --> ErrorNotEnough --> Pause --> Exit
    SpaceEnough -- 是 --> RobocopyError
    RobocopyError -- 是 --> RobocopyFail --> Pause --> Exit
    RobocopyError -- 否 --> RobocopyOk --> Pause --> Exit