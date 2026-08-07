# ⚔️ Boss Fight Simulator
Boss Battle Simulator game, where 3 classes of heroes fight a powerful boss with differing strategies.

<img width="1440" height="576" alt="ComfyUI_00113_" src="https://github.com/user-attachments/assets/31f9d98a-64e5-4a3d-b5ed-cbdbc5d78925" />

A turn-based tactical combat game built in Godot 4.

---

## 🎮 Installation & Running the Game

### 🪟 Windows 
1. Download and extract the **Windows** `.zip` from the [Latest Release](../../releases).
2. Run `Boss_Fight_Sim.exe`.
3. (Optional) Keep the .pak bundled in the folder!

### 🍎 Complete macOS Setup & Launch Guide

If you're running into macOS Gatekeeper or execution permission issues, follow these steps to get **Boss Fight Simulator** running smoothly.

---

#### Section 1: Downloading & Bypassing Gatekeeper

1. Download the **`macOS`** `.zip` file from the [Latest Release](../../releases).
2. Extract the `.zip` archive and move `Boss_Fight_Sim.app` into your **Applications** folder.
3. **First-Time Launch Step:**
   * Right-click (or hold `Control` and click) on `Boss_Fight_Sim.app`.
   * Select **Open** from the context menu.
   * Click **Open** when prompted by the macOS security window.
   *(Note: You only need to do this on the first launch—subsequent launches work via normal double-clicking!)*

---

#### Section 2: Granting Executable Permissions (Terminal Fix)

Because builds exported from non-Mac operating systems often lose their executable permissions, macOS may refuse to open the app. You can grant permissions in seconds using Terminal:

1. Open **Terminal** (press `⌘ + Space`, type `Terminal`, and press `Return`).
2. Navigate to the folder containing the game using the `cd` command (e.g., `cd ~/Downloads` or `cd /Applications`).
3. Run the following executable command:
   ```bash
   chmod +x Boss_Fight_Sim
   ```
4. The file icon should update to a terminal application icon, indicating it is now ready to run.

---

#### Section 3: Launching via Package Contents (Full Step-by-Step)

If macOS is still restricting launch permissions, you can manually target the core executable file inside the application package:

1. Download and unzip the game package.
2. Locate `Boss_Fight_Sim.app` in your file manager.
3. Right-click the `.app` file and select **Show Package Contents**.
4. Open the **`Contents`** folder, then open the **`MacOS`** folder inside it.
5. Open your **Terminal** application.
6. In Terminal, type `chmod +x ` (make sure to include a space after `+x`).
7. Drag the `Boss_Fight_Sim` executable file directly from the `MacOS` folder into your Terminal window (this automatically pastes its exact directory path).
8. Press `Return` on your keyboard to apply permissions.
9. You can now double-click the executable or `.app` file to launch the game freely!

### 🐧 Linux
1. Download and extract the **Linux** `.zip` from the [Latest Release](../../releases).
2. Make the executable runnable: `chmod +x Boss_Fight_Sim.x86_64`
3. Launch via terminal: `./Boss_Fight_Sim.x86_64`

---

## ✨ Recent Updates (v1.5.0 Patch)

* **Party Battle Overhaul**
  * Fully resolved structural issues with the Party Battle system and corrected the boss attack vector so lunges dash strictly left.
* **Party Rebalancing**
  * Integrated a physical vulnerability multiplier (+40% physical damage taken) so the Fighter hits much harder without affecting Solo Mode balance.
  * Increased boss attack damage and AOE frequency to enforce active Mage healing rotations.
* **Visual FX & Animations**
  * Added a continuous crimson afterimage ghost trail (*Roaring Knight* style) drifting behind the boss.
  * Implemented a continuous sine-wave float oscillation for natural hovering motion on the boss puppet layer.
