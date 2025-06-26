# backup_userfiles_robocopy.bat 流程圖

```mermaid
flowchart TD
    Start([開始])
    AdminCheck{有系統管理員權限？}
    TryElevate{提升權限成功？}
    ArgsHelp{"參數為 -?"}
    ArgsGiven{"參數空白？"}
    DstGiven{"有目標路徑？"}
    UserGiven{"有用戶名稱？"}
    InteractiveInput[互動模式輸入來源路徑、用戶ID、目標路徑]
    Main[進入主流程]
    Confirm{"確認繼續？(Y/N)"}
    SrcExist{"來源資料夾存在？"}
    DstExist{"目標資料夾存在？"}
    MkdirOk{"建立目標資料夾成功？"}
    SrcSizeOk{"取得來源資料夾大小成功？"}
    DstFreeOk{"取得目標磁碟剩餘空間成功？"}
    SpaceEnough{"目標空間>=來源大小？"}
    RobocopyError{"robocopy執行完回傳碼>=8？"}
    ShowUsage[顯示使用說明並結束]
    Cancel[已取消作業]
    Exit[結束]
    ErrorAdmin[顯示「請重新用系統管理員執行」並退出]
    ErrorSrc[顯示來源不存在並退出]
    ErrorMkdir[顯示建立失敗並退出]
    ErrorSrcSize[顯示無法取得來源大小並退出]
    ErrorDstFree[顯示無法取得目標空間並退出]
    ErrorNotEnough[顯示空間不足並退出]
    RobocopyOk[備份完成]
    RobocopyFail[robocopy 發生嚴重錯誤，檢查 log]
    Pause[按任意鍵結束]

    Start --> AdminCheck
    AdminCheck -- 是 --> ArgsHelp
    AdminCheck -- 否 --> TryElevate
    TryElevate -- 是 --> ArgsHelp
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