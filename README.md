# 記帳 App (Accounting)

個人使用的記帳 iPhone App，使用 SwiftUI 開發。

## 環境需求

- **macOS**：需安裝 Xcode（從 App Store 下載）
- **iPhone**：iOS 16.0 或以上
- **Apple ID**：用於在真機上部署與測試

---

## 步驟一：Hello World 部署測試

### 1. 開啟專案

1. 用 **Xcode** 開啟專案：
   ```bash
   open /Users/linjunhan/git/Accounting/Accounting.xcodeproj
   ```
2. 或雙擊 `Accounting.xcodeproj` 開啟

### 2. 在模擬器上測試

1. 在 Xcode 頂部選擇模擬器（例如：iPhone 15）
2. 按 `⌘ + R` 或點擊 ▶️ 執行
3. 若看到「Hello, 記帳!」與「部署成功！」即表示成功

### 3. 部署到自己的 iPhone

#### 3.1 連接 iPhone

1. 用 USB 線連接 iPhone 到 Mac
2. 若 iPhone 詢問「要信任此電腦嗎？」，選擇「信任」
3. 在 iPhone 上解鎖並保持螢幕開啟

#### 3.2 設定開發者帳號

1. 在 Xcode 左側點選藍色專案圖示 **Accounting**
2. 選擇 **Accounting** target
3. 點選 **Signing & Capabilities**
4. 勾選 **Automatically manage signing**
5. 在 **Team** 選擇你的 Apple ID（若沒有，點 **Add Account** 登入）

#### 3.3 信任開發者憑證（首次部署）

1. 在 iPhone 上：**設定 → 一般 → VPN 與裝置管理**
2. 找到你的 Apple ID 開發者憑證
3. 點選 **信任**，完成後即可開啟 App

#### 3.4 執行到 iPhone

1. 在 Xcode 頂部裝置選單選擇你的 iPhone
2. 按 `⌘ + R` 執行
3. 若出現「無法驗證開發者」，請依 3.3 完成信任設定

### 4. 常見問題

| 問題 | 解決方式 |
|------|----------|
| 找不到 Team | 在 Xcode 登入 Apple ID：Xcode → Settings → Accounts |
| 憑證錯誤 | 確認 Bundle ID 唯一，可改為 `com.你的名字.accounting` |
| 無法安裝到 iPhone | 檢查 USB 連接、iPhone 解鎖、信任電腦 |
| 需要較新 Xcode | 從 App Store 更新 Xcode 至最新版 |

---

## 專案結構

```
Accounting/
├── Accounting.xcodeproj    # Xcode 專案檔
├── Accounting/             # 原始碼
│   ├── AccountingApp.swift # App 進入點
│   ├── ContentView.swift   # 主畫面
│   └── Assets.xcassets    # 圖片與資源
├── README.md
└── DEVELOPMENT_PLAN.md    # 開發計畫
```

---

## 後續開發

完成 Hello World 部署測試後，請參考 `DEVELOPMENT_PLAN.md` 依步驟實作各項功能。
