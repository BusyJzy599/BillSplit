# Setup Instructions

## 1. Create Xcode Project

1. Open Xcode
2. Select **File → New → Project**
3. Choose **iOS → App** template
4. Configure:
   - **Name:** `BillSplit`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Minimum Deployment:** iOS 17.0+
5. Save to: `/Users/zy/Desktop/swl/BillSplit/`

## 2. Add Firebase via Swift Package Manager

1. In Xcode, select **File → Add Package Dependencies...**
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Choose version: **Up to Next Major** (latest)
4. Select the following packages:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseFirestoreSwift`
5. Click **Add Package**

## 3. Add Swift Files to Xcode

1. In Xcode's Project Navigator, right-click the `BillSplit` group
2. Select **Add Files to "BillSplit"...**
3. Navigate to `/Users/zy/Desktop/swl/BillSplit/`
4. Select all `.swift` files across `Models/`, `Services/`, `ViewModels/`, `Views/`, `Utils/`
5. Ensure **Copy items if needed** is **checked**
6. Ensure **Add to targets: BillSplit** is **selected**
7. Click **Add**

## 4. Verify Build

1. Press **Cmd+B** to build
2. Resolve any package resolution issues if prompted
