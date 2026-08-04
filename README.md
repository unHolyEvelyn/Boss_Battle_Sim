# ⚔️ Boss Fight Simulator
Boss Battle Simulator game, where 3 classes of heroes fight a powerful boss with differing strategies.

<img width="1440" height="576" alt="ComfyUI_00113_" src="https://github.com/user-attachments/assets/31f9d98a-64e5-4a3d-b5ed-cbdbc5d78925" />

A turn-based tactical combat game built in Godot 4.

## STOP REPORTING THE MOUSE DOESN'T WORK
I KNOW.  I'm trying to take out any remnant of it having worked and move forward with 0 mouse functionality so there's less UI confusion.  My plan was always to make it keyboard or controller only, like most RPGs.

---

## 🎮 Installation & Running the Game

### 🪟 Windows 
1. Download and extract the **Windows** `.zip` from the [Latest Release](../../releases).
2. Run `Boss_Fight_Sim.exe`.
3. (Optional) Keep the .pak bundled in the folder!

### 🍎 macOS
1. Download and extract the **macOS** `.zip` from the [Latest Release](../../releases).
2. Move `Boss_Fight_Sim.app` to your **Applications** folder.
3. **First-Time Launch (Bypassing Gatekeeper):**
   * Right-click (or `Ctrl + Click`) on `Boss_Fight_Sim.app`.
   * Select **Open** from the menu.
   * Click **Open** again in the security prompt window.  
   *(You only need to do this once! Future launches work via normal double-click).*

A permissions issue stemming from me compiling this game on Windows occurs, so these next few steps will allow you to run the program as an executable.
1. Open your terminal and use the command cd to go to the directory the game is stored (or open the terminal in the folder).
2. type in `chmod +x Boss_Fight_Sim`
3. The game's icon should become the terminal icon.  Feel free to create a shortcut as needed.

One of my beta testers is concerned that Mac Users are mouth breathers (and honestly for the price you paid for the world's worst OS and hardware you probably ARE) but here, since you need your hand held as a widdle baby:
1. Download the file.
2. Unzip the file.
3. Find the file that's supposed to be the executable on your dogshit system.
4. Right click it.
5. Select "Show package contents".
6. Open the "Contents" folder.
7. Open the MacOS folder.
8. Open your terminal and type the executable command WITHOUT `Boss Fight Sim`.
9. Drag that into your terminal (because Apple doesn't know the concept of "right click > open in terminal").
10. Hit your return key.
11. Double click to open.

Now that you figured out how to use your own Operating System, promptly sell it to the nearest fool for as high a price as you can and buy a real computer.

Alternatively Mac users are free to pay for the 100 dollar subscription license it would cost me to bypass this, but for a free poorly made minigame I think you can jump this hurdle.

### 🐧 Linux
1. Download and extract the **Linux** `.zip` from the [Latest Release](../../releases).
2. Make the executable runnable: `chmod +x Boss_Fight_Sim.x86_64`
3. Launch via terminal: `./Boss_Fight_Sim.x86_64`

---

## ✨ Recent Updates (v1.3.0 Overhaul)

* **Pure Controller & Arcade Navigation**
  * Mouse controls completely stripped. Full navigation now locked strictly to D-pad, stick, and keyboard inputs.
* **Hard Mode Progression**
  * Added a Hard Mode challenge toggle for all heroes!
  * Hard Mode unlocks per character once you reach **5 Victories** on standard difficulty.
* **Mage Class Buffs**
  * Increased base Health and Defense stats for the Mage to improve solo viability.
* **Save Data & Persistent Progression**
  * Player stats and win counts now automatically save to disk (`user://save_data.cfg`) and persist across sessions.
* **UI & Visual Refresh**
  * Cleaned up character select layout with clear `WINS: X` indicators and dynamic hero-themed selection borders.
