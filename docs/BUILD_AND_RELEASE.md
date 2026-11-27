# Getting new builds onto your iPhone (free)

**Now automatic again (Nov 27):** the GitHub project is public, which makes GitHub's builds free. Every change to `main` builds and uploads to TestFlight by itself. What follows are backups.

GitHub keeps the code (free). It no longer builds the app: its free Mac minutes ran out
after a few changes a month. There are two free ways to get a build into TestFlight.

| | Xcode Cloud (main way) | Your Mac (backup) |
|---|---|---|
| Cost | Free: 25 hours a month come with the Apple Developer membership | Free |
| When | Automatically, every time new code reaches `main` | When you run one command |
| You need to be at the Mac | Only once, to set it up | Every time |

None of this changes the app or where your data lives (your iPhone and your iCloud).

---

## A. Set up Xcode Cloud (once, about 15-20 minutes)

1. On the Mac, open **Terminal** and go to the project folder:
   ```bash
   cd ~/Adaptive-Fitness
   ```
   (If it lives somewhere else, `cd` there instead.)
2. Get the newest code and make the Xcode project:
   ```bash
   git checkout main
   ```
   ```bash
   git pull
   ```
   ```bash
   xcodegen generate
   ```
   ```bash
   open Hybrid12.xcodeproj
   ```
3. In Xcode: menu **Integrate > Create Workflow…** (in some versions: the **Report navigator** (the speech-bubble icon on the left) **> Cloud > Get Started**).
4. Pick the **Hybrid12** app (not the widget) and click **Next**.
5. When it asks to connect to GitHub, click **Grant Access** and approve **Adaptive-Fitness** on the GitHub page that opens. Come back to Xcode.
6. Xcode shows a starting workflow. Click **Edit Workflow** (or **Manage Workflows**) and set:
   - **Start Conditions:** *Branch Changes*, branch **main**. Remove any other start condition.
   - **Actions:** keep **Archive - iOS**. Set its **Deployment Preparation** to **TestFlight (Internal Testing Only)**.
   - **Post-Actions:** click **+ > TestFlight Internal Testing**, and pick your tester group (or create one with your Apple ID in it).
   - **Environment:** leave Xcode on *Latest Release*. To keep WHOOP working, add two **Environment Variables**:
     `WHOOP_CLIENT_ID` and `WHOOP_CLIENT_SECRET` (tick **Secret** on the second). The values are in `Config/Secrets.xcconfig` (or `~/Downloads/whoop.txt`). Skip this and the cloud builds have WHOOP turned off.
7. Click **Save**, then **Start Build**.
8. **Build numbers (one time):** in a web browser go to **appstoreconnect.apple.com > Apps > Hybrid 12 > Xcode Cloud > Settings > Build Number**, and set the next build number to **20261200**. (Your old builds are numbered like 20261107.2002; TestFlight only accepts a higher number.)

The first build takes about 20-30 minutes. You can watch it in Xcode's Report navigator, or in App Store Connect under Xcode Cloud. It then appears in TestFlight on your phone.

**If the first build says it can't find the project:** tell Claude. The fix is to store the Xcode project in git, a small change.

---

## B. Build from your Mac instead (backup, any time)

Plug in the Crucial drive, then in Terminal:

```bash
cd ~/Adaptive-Fitness
```
```bash
git pull
```
```bash
./scripts/upload-testflight.sh
```

It runs the tests, builds the app and uploads it, keeping all its files on the Crucial drive
(`Hybrid12Build` folder). The build shows up in TestFlight in 10-30 minutes. If it stops with
an error, copy the red lines to Claude.

---

## Make sure GitHub can never charge you

On github.com: your picture (top right) **> Settings > Billing and licensing**:

- **Plan** says *Free*.
- **Budgets and alerts** (or *Spending limits*): Actions limit is **$0**.
- No failed payment waiting; remove a saved card if you don't want one there.

The old GitHub robots still exist but only run if you start them by hand from the Actions tab.
