# Fix Windows build: NuGet download failed

The Windows build needs **nuget.exe**. If your network blocks or times out connecting to `dist.nuget.org`, install NuGet manually so the build does not try to download it.

## Step 1: Get nuget.exe

**Option A – Download in browser (try this first)**  
Open this URL in your browser (Chrome/Edge):

**https://dist.nuget.org/win-x86-commandline/v6.0.0/nuget.exe**

- If it downloads, save it and go to Step 2.
- If it fails, try **Option B**.

**Option B – Use another network**  
- Connect with **mobile hotspot** or another Wi‑Fi, then open the URL above and download, **or**
- On another PC that has internet, download the file and copy it to this PC (e.g. USB or cloud).

**Option C – winget (if it works on your network)**  
In PowerShell (Run as Administrator):

```powershell
winget install Microsoft.NuGet
```

Then find where it was installed (e.g. under `Program Files`), and add that folder to PATH (Step 2). If winget also times out, use A or B.

## Step 2: Add NuGet to PATH

1. Create a folder, e.g. **`C:\NuGet`**.
2. Put **nuget.exe** in that folder (so you have `C:\NuGet\nuget.exe`).
3. Add that folder to your system **PATH**:
   - Press **Win + R**, type **`sysdm.cpl`**, Enter.
   - **Advanced** tab → **Environment Variables**.
   - Under **System variables**, select **Path** → **Edit** → **New** → enter **`C:\NuGet`** (or your folder).
   - OK to close all dialogs.
4. **Close and reopen** PowerShell (and Cursor/IDE) so the new PATH is picked up.

## Step 3: Clean and rebuild

In PowerShell (in your project folder):

```powershell
cd "C:\Users\Moeez\Nutri-Sense"
flutter clean
flutter run -d windows
```

The build should find `nuget` on PATH and skip the download.

## Check that NuGet is found

In a **new** PowerShell window, run:

```powershell
nuget
```

You should see NuGet help output, not “not recognized”.

## If you still can’t download NuGet

- Run the app in the browser instead: **`flutter run -d chrome`** (no NuGet needed).
- Or run on an **Android** device/emulator if you have it set up.
